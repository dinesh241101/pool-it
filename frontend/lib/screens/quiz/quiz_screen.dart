import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';

class QuizScreen extends StatefulWidget {
  final String url;

  const QuizScreen({super.key, required this.url});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (url) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (_) {
              if (mounted) setState(() => _hasError = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } catch (_) {
      _hasError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz & Riddles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () {
              if (!_hasError) _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError) const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('Could not load the quiz.', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    widget.url,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
