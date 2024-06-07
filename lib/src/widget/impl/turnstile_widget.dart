import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:cloudflare_turnstile/src/html_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cloudflare_turnstile/src/widget/interface.dart' as i;

class CloudFlareTurnstile extends StatefulWidget implements i.CloudFlareTurnstile {
  @override
  final String siteKey;

  @override
  final String? action;

  @override
  final String? cData;

  @override
  final String baseUrl;

  @override
  final TurnstileOptions options;

  @override
  final TurnstileController? controller;

  @override
  final i.OnTokenRecived? onTokenRecived;

  @override
  final i.OnTokenExpired? onTokenExpired;

  @override
  final i.OnError? onError;

  CloudFlareTurnstile({
    super.key,
    required this.siteKey,
    this.action,
    this.cData,
    this.baseUrl = 'http://localhost/',
    TurnstileOptions? options,
    this.controller,
    this.onTokenRecived,
    this.onTokenExpired,
    this.onError,
  }) : options = options ?? TurnstileOptions() {
    if (action != null) {
      assert(
        action!.length <= 32 && RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(action!),
        'action must be contain up to 32 characters including _ and -.',
      );
    }

    if (cData != null) {
      assert(
        cData!.length <= 32 && RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(cData!),
        'action must be contain up to 32 characters including _ and -.',
      );
    }
  }

  @override
  State<CloudFlareTurnstile> createState() => _CloudFlareTurnstileState();
}

class _CloudFlareTurnstileState extends State<CloudFlareTurnstile> {
  late String data;

  String? widgetId;

  bool _isWidgetReady = false;

  // final InAppWebViewSettings _settings = InAppWebViewSettings(
  //   disableHorizontalScroll: true,
  //   verticalScrollBarEnabled: false,
  //   transparentBackground: true,
  //   disallowOverScroll: true,
  //   disableVerticalScroll: true,
  //   supportZoom: false,
  //   useWideViewPort: false,
  // );

  final String _readyJSHandler = 'window.flutter_inappwebview.callHandler(`TurnstileReady`, true);';
  final String _tokenRecivedJSHandler = 'window.flutter_inappwebview.callHandler(`TurnstileToken`, token);';
  final String _errorJSHandler = 'window.flutter_inappwebview.callHandler(`TurnstileError`, code);';
  final String _tokenExpiredJSHandler = 'window.flutter_inappwebview.callHandler(`TokenExpired`);';
  final String _widgetCreatedJSHandler = 'window.flutter_inappwebview.callHandler(`TurnstileWidgetId`, widgetId);';

  @override
  void initState() {
    super.initState();
    data = htmlData(
      siteKey: widget.siteKey,
      action: widget.action,
      cData: widget.cData,
      options: widget.options,
      onTurnstileReady: _readyJSHandler,
      onTokenRecived: _tokenRecivedJSHandler,
      onTurnstileError: _errorJSHandler,
      onTokenExpired: _tokenExpiredJSHandler,
      onWidgetCreated: _widgetCreatedJSHandler,
    );
  }

  _onWebViewCreated(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'TurnstileToken',
      callback: (args) {
        widget.controller?.newToken = args[0];
        widget.onTokenRecived?.call(args[0]);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'TurnstileError',
      callback: (args) {
        widget.onError?.call(args[0]);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'TurnstileWidgetId',
      callback: (args) {
        widgetId = args[0];
        widget.controller?.widgetId = args[0];
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'TurnstileReady',
      callback: (args) {
        setState(() {
          _isWidgetReady = args[0];
        });
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'TokenExpired',
      callback: (args) {
        widget.onTokenExpired?.call();
      },
    );

    widget.controller?.setConnector(controller);
  }

  final double _borderWidth = 2.0;

  Widget get _view => InAppWebView(
        initialData: InAppWebViewInitialData(
          data: data,
          baseUrl: Uri.parse(widget.baseUrl),
        ),
        onWebViewCreated: (controller) => _onWebViewCreated(controller),
        onConsoleMessage: (controller, consoleMessage) {
          if (consoleMessage.message.contains(RegExp('Turnstile'))) {
            debugPrint(consoleMessage.message);
            if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
              widget.onError?.call(consoleMessage.message);
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          widget.onError?.call(message);
        },
      );

  @override
  Widget build(BuildContext context) {
    return widget.options.mode == TurnstileMode.invisible
        ? SizedBox.shrink(child: _view)
        : AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _isWidgetReady ? widget.options.size.width + _borderWidth : 0,
            height: _isWidgetReady ? widget.options.size.height + _borderWidth : 0,
            child: _view,
          );
  }
}
