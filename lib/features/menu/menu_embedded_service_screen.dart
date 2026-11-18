import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

class MenuEmbeddedServiceScreen extends StatefulWidget {
  const MenuEmbeddedServiceScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<MenuEmbeddedServiceScreen> createState() => _MenuEmbeddedServiceScreenState();
}

class _MenuEmbeddedServiceScreenState extends State<MenuEmbeddedServiceScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() {
              _failed = false;
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reload() async {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.textPrimary,
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              } else if (mounted) {
                Navigator.of(context).maybePop();
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            widget.title,
            style: AppText.title.copyWith(color: AppColors.textPrimary),
          ),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_progress < 100 && !_failed)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface2,
                ),
              ),
            if (_failed)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.bg,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 42, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            'Layanan tidak bisa dimuat.',
                            style: AppText.title
                                .copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Periksa koneksi internet, lalu coba lagi.',
                            textAlign: TextAlign.center,
                            style: AppText.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
