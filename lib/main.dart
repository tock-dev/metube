import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      fullScreen: true,
      titleBarStyle: TitleBarStyle.hidden,
      center: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(MaterialApp(home: Application()));
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  late final WebViewController _controller;
  RawDatagramSocket? _udpSocket;
  HttpServer? _httpServer;
  String _localIp = '127.0.0.1';
  String deviceName = 'MeTube';

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (SmartHub; SMART-TV; Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

    final Object platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
      AndroidWebViewController.enableDebugging(true);
    }

    _controller.loadRequest(Uri.parse('https://www.youtube.com/tv'));

    // Start background network services immediately at launch
    _bootDIALEngine();
  }

  void _bootDIALEngine() async {
    if (deviceName == 'MeTube') {
      var dip = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        var deviceInfo = await dip.androidInfo;
        deviceName =
            '${deviceInfo.name} / ${deviceInfo.manufacturer} ${deviceInfo.model}';
      } else if (Platform.isIOS) {
        var deviceInfo = await dip.iosInfo;
        deviceName = '${deviceInfo.name} / ${deviceInfo.modelName}';
      } else if (Platform.isLinux) {
        var deviceInfo = await dip.linuxInfo;
        deviceName = '${deviceInfo.prettyName} / ${deviceInfo.id}';
      } else if (Platform.isMacOS) {
        var deviceInfo = await dip.macOsInfo;
        deviceName = '${deviceInfo.computerName} / ${deviceInfo.modelName}';
      } else if (Platform.isWindows) {
        var deviceInfo = await dip.windowsInfo;
        deviceName =
            '${deviceInfo.userName}\'s ${deviceInfo.computerName} / ${deviceInfo.productName}';
      }
    }
    try {
      _localIp = await _getLocalIpAddress();

      // 1. Start HTTP Server on Port 8080
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _listenHTTP(_httpServer!);
      print("🚀 DIAL HTTP Server alive at http://$_localIp:8080/dial/dd.xml");

      // 2. Start SSDP Multicast Socket on Port 1900
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 1900);
      _udpSocket!.joinMulticast(InternetAddress('239.255.255.250'));
      _listenSSDP(_udpSocket!);
      print("📡 SSDP Listener bound and watching multicast targets...");
    } catch (e) {
      print("Error booting DIAL components: $e");
    }
  }

  void _listenHTTP(HttpServer server) async {
    await for (HttpRequest request in server) {
      print("Incoming API Hit: ${request.uri.path} [${request.method}]");

      // Add global headers to handle aggressive mobile client validation
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add(
        'Access-Control-Expose-Headers',
        'Application-URL',
      );

      if (request.uri.path == '/dial/dd.xml') {
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        request.response.headers.add(
          'Application-URL',
          'http://$_localIp:8080/dial/apps/',
        );

        // Fully compliant UPnP schema required by the YouTube client
        String xml =
            '''<?xml version="1.0" encoding="utf-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dial="urn:dial-multiscreen-org:schemas:dial">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:dialreceiver:1</deviceType>
    <friendlyName>$deviceName</friendlyName>
    <manufacturer>tockdev</manufacturer>
    <modelName>MeTube Receiver</modelName>
    <UDN>uuid:fb2772a0-4b2e-11e2-bcfd-0800200c9a66</UDN>
    <serviceList>
      <service>
        <serviceType>urn:dial-multiscreen-org:service:dial:1</serviceType>
        <serviceId>urn:dial-multiscreen-org:serviceId:dial</serviceId>
        <SCPDURL>/dial/scpd.xml</SCPDURL>
        <controlURL>/dial/control</controlURL>
        <eventSubURL>/dial/event</eventSubURL>
      </service>
    </serviceList>
  </device>
</root>''';

        request.response.write(xml);
        await request.response.close();
      } else if (request.uri.path == '/dial/apps/YouTube') {
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );

        if (request.method == 'GET') {
          String appXml = '''<?xml version="1.0" encoding="UTF-8"?>
<service xmlns="urn:dial-multiscreen-org:schemas:dial" dialVer="2.1">
  <name>YouTube</name>
  <options allowStop="true" />
  <state>running</state>
</service>''';
          request.response.write(appXml);
          await request.response.close();
        } else if (request.method == 'POST') {
          String body = await utf8.decoder.bind(request).join();
          print("Phone link parameters: $body");

          request.response.statusCode = HttpStatus.created;
          await request.response.close();

          // Construct the deep link URL with the exact parameters the phone provided
          // YouTube's web app parses these query arguments natively on boot!
          final String targetUrl = 'https://www.youtube.com/tv?$body';
          print("Routing WebView straight to: $targetUrl");

          // Force the webview to navigate directly to the pairing session URL
          _controller.loadRequest(Uri.parse(targetUrl));
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }
  }

  void _listenSSDP(RawDatagramSocket socket) {
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = socket.receive();
        if (dg == null) return;

        String rawMessage = utf8.decode(dg.data);

        // FIXED: Now catches the exact text signature your phone is broadcasting!
        if (rawMessage.contains('urn:dial-multiscreen-org:service:dial:1')) {
          print("🎯 Matching DIAL target spotted! Replying to phone...");

          String ssdpResponse =
              "HTTP/1.1 200 OK\r\n"
              "LOCATION: http://$_localIp:8080/dial/dd.xml\r\n"
              "ST: urn:dial-multiscreen-org:service:dial:1\r\n"
              "EXT:\r\n"
              "BOOTID.UPNP.ORG: 1\r\n"
              "SERVER: Flutter/Linux/Mac/Windows UPnP/1.0 MeTube/1.0\r\n"
              "\r\n";

          socket.send(utf8.encode(ssdpResponse), dg.address, dg.port);
        }
      }
    });
  }

  Future<String> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return '127.0.0.1';
  }

  @override
  void dispose() {
    _udpSocket?.close();
    _httpServer?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: WebViewWidget(controller: _controller),
    );
  }
}
