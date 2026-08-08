import 'package:flutter/material.dart';
import 'package:prasowka/theme/app_theme.dart';

class ScrollToTopWrapper extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;
  final double threshold;

  const ScrollToTopWrapper({
    super.key,
    required this.scrollController,
    required this.child,
    this.threshold = 600,
  });

  @override
  State<ScrollToTopWrapper> createState() => _ScrollToTopWrapperState();
}

class _ScrollToTopWrapperState extends State<ScrollToTopWrapper> {
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final show = widget.scrollController.offset > widget.threshold;
    if (show != _showBackToTop) {
      setState(() => _showBackToTop = show);
    }
  }

  void _scrollToTop() {
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBackToTop)
          Positioned(
            right: 16,
            bottom: 80,
            child: FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
              elevation: 4,
              child: const Icon(Icons.arrow_upward),
            ),
          ),
      ],
    );
  }
}
