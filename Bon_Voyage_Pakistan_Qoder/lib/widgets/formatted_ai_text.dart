import 'package:flutter/material.dart';

/// A rich text widget that parses HTML styling tags (<b>, <i>, <u>)
/// and converts them into Flutter TextSpans without using external packages.
class FormattedAiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const FormattedAiText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = _parseHtmlTags(text, defaultStyle);

    return RichText(
      text: TextSpan(children: spans, style: defaultStyle),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static List<InlineSpan> _parseHtmlTags(String rawText, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final tagRegex = RegExp(r'<(/?)(b|i|u)>', caseSensitive: false);

    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;

    int lastIndex = 0;
    for (final match in tagRegex.allMatches(rawText)) {
      if (match.start > lastIndex) {
        final chunk = rawText.substring(lastIndex, match.start);
        if (chunk.isNotEmpty) {
          spans.add(TextSpan(
            text: chunk,
            style: _buildCurrentStyle(baseStyle, isBold, isItalic, isUnderline),
          ));
        }
      }

      final isClosing = match.group(1) == '/';
      final tag = match.group(2)?.toLowerCase();

      if (tag == 'b') {
        isBold = !isClosing;
      } else if (tag == 'i') {
        isItalic = !isClosing;
      } else if (tag == 'u') {
        isUnderline = !isClosing;
      }

      lastIndex = match.end;
    }

    if (lastIndex < rawText.length) {
      final trailing = rawText.substring(lastIndex);
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(
          text: trailing,
          style: _buildCurrentStyle(baseStyle, isBold, isItalic, isUnderline),
        ));
      }
    }

    return spans;
  }

  static TextStyle _buildCurrentStyle(
    TextStyle base,
    bool isBold,
    bool isItalic,
    bool isUnderline,
  ) {
    TextStyle s = base;
    if (isBold) {
      s = s.copyWith(fontWeight: FontWeight.w700);
    }
    if (isItalic) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }
    if (isUnderline) {
      s = s.copyWith(
        decoration: isUnderline
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    }
    return s;
  }
}
