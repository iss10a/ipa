import 'dart:async';

import 'package:flutter/material.dart';

/// Debounced search input so a large catalog is not re-filtered on every stroke.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'ابحث…',
    this.autofocus = false,
    this.initialValue = '',
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;
  final String initialValue;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      widget.onChanged(value);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  _debounce?.cancel();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
        isDense: true,
      ),
    );
  }
}
