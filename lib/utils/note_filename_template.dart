import 'package:gitjournal/utils/datetime.dart';
import 'package:intl/intl.dart';

final Map<String, Set<String>> validTemplateVariablesAndOptions = {
  'date': {'fmt'},
  'title': {
    'lowercase',
    'uppercase',
    'snake_case',
    'kebab_case',
    'max_length',
    'default'
  },
  'uuidv4': {},
};

class FileNameTemplate {
  List<_TemplateSegment> segments;

  FileNameTemplate(this.segments);

  static FileNameTemplate parse(String template) {
    try {
      return FileNameTemplate(_parseTemplate(template));
    } on Exception catch (e) {
      throw Exception("Problem parsing template: $e");
    }
  }

  FileNameTemplateValidationResult validate() {
    final segmentsIncludeTitle =
        segments.any((segment) => segment.variableName == 'title');
    final segmentsIncludeDate =
        segments.any((segment) => segment.variableName == 'date');
    final segmentsIncludeUuid =
        segments.any((segment) => segment.variableName == 'uuidv4');
    if (!segmentsIncludeTitle && !segmentsIncludeDate && !segmentsIncludeUuid) {
      return const FileNameTemplateValidationFailure(
          "Template must include {{title}} or {{date}} or {{uuidv4}}");
    }
    final segmentVariableErrors = segments.expand((segment) {
      if (!segment.isVariable()) {
        return [];
      }
      final optionNames =
          Set.from(segment.variableOptions?.keys.toList() ?? []);
      final validOptionNames =
          validTemplateVariablesAndOptions[segment.variableName] ?? {};
      final invalidOptionNames = optionNames.difference(validOptionNames);
      if (invalidOptionNames.isNotEmpty) {
        return [
          "Invalid option(s) for variable ${segment.variableName}: ${invalidOptionNames.join(', ')}"
        ];
      }

      return [];
    });
    if (segmentVariableErrors.isNotEmpty) {
      return FileNameTemplateValidationFailure(segmentVariableErrors.join(';'));
    }

    return const FileNameTemplateValidationSuccess();
  }

  String render({
    required DateTime date,
    required String root,
    required String Function() uuidv4,
    String? title,
  }) {
    final renderedSegments = segments.map((segment) {
      final invalidOptions = segment.variableOptions?.keys.where((key) {
        final validOptions =
            validTemplateVariablesAndOptions[segment.variableName];
        return validOptions != null ? validOptions.contains(key) : false;
      }).toList();
      if (invalidOptions != null && invalidOptions.isNotEmpty) {
        throw Exception(
            "Invalid option(s) for variable ${segment.variableName}: ${invalidOptions.join(', ')}");
      }

      if (segment.variableName == null) {
        return segment.text;
      } else if (segment.variableName == 'date') {
        return _renderDate(date, segment.variableOptions);
      } else if (segment.variableName == 'title') {
        return _renderTitle(title, segment.variableOptions);
      } else if (segment.variableName == 'uuidv4') {
        return uuidv4();
      } else {
        throw Exception(
            "Unknown template variable {{${segment.variableName}}}");
      }
    });
    return renderedSegments.join();
  }
}

abstract class FileNameTemplateValidationResult {
  const FileNameTemplateValidationResult();
}

class FileNameTemplateValidationSuccess
    extends FileNameTemplateValidationResult {
  const FileNameTemplateValidationSuccess();
}

class FileNameTemplateValidationFailure
    extends FileNameTemplateValidationResult {
  const FileNameTemplateValidationFailure(this.message);

  final String message;
}

List<_TemplateSegment> _parseTemplate(String template) {
  final List<_TemplateSegment> segments = [];
  var resolvingVariable = false;

  template.splitMapJoin(
    RegExp("{{|}}"),
    onMatch: (match) {
      if (match[0] == '{{') {
        if (resolvingVariable) {
          throw Exception("Unexpected '{{' at ${match.start}");
        }
        resolvingVariable = true;
      } else {
        if (!resolvingVariable) {
          throw Exception("Unexpected '}}' at ${match.start}");
        }
        resolvingVariable = false;
      }
      return '';
    },
    onNonMatch: (text) {
      if (resolvingVariable) {
        final variableSegments = text.split(':');
        final variableName = variableSegments[0];
        final List<String> optionsSegments =
            variableSegments.length == 1 ? [] : variableSegments[1].split(',');

        final variableOptions =
            Map.fromEntries(optionsSegments.map((optionText) {
          final optionSegments = optionText.split('=');
          if (optionSegments.length > 2) {
            throw Exception("Invalid option for $variableName `$optionText`");
          }
          return MapEntry(
            optionSegments[0],
            optionSegments.length == 1 ? 'true' : optionSegments[1],
          );
        }));
        segments.add(_TemplateSegment(text, variableName, variableOptions));
      } else {
        segments.add(_TemplateSegment(text, null, null));
      }
      return text;
    },
  );

  if (resolvingVariable) {
    throw Exception("Unexpected end of template");
  }

  return segments;
}

class _TemplateSegment {
  final String text;
  String? variableName;
  Map<String, String>? variableOptions;

  _TemplateSegment(this.text, this.variableName, this.variableOptions);

  isVariable() => variableName != null;

  validate() {}
}

String _renderDate(DateTime date, Map<String, String>? variableOptions) {
  if (variableOptions == null || variableOptions['fmt'] == null) {
    return toSimpleDateTime(date);
  }

  return DateFormat(variableOptions['fmt']).format(date);
}

String _renderTitle(String? titleInput, Map<String, String>? variableOptions) {
  final defaultTitle = variableOptions?['default'] ?? 'untitled';
  var title = titleInput ?? defaultTitle;
  if (variableOptions == null) {
    return title;
  }

  if (variableOptions['lowercase'] == 'true') {
    title = title.toLowerCase();
  } else if (variableOptions['uppercase'] == 'true') {
    title = title.toUpperCase();
  }

  if (variableOptions['snake_case'] == 'true') {
    title = title.replaceAll(RegExp(r'\s+'), '_');
  } else if (variableOptions['kebab_case'] == 'true') {
    title = title.replaceAll(RegExp(r'\s+'), '-');
  }

  if (variableOptions['max_length'] != null) {
    try {
      final maxLength = int.parse(variableOptions['max_length']!);
      if (title.length > maxLength) {
        title = title.substring(0, maxLength);
      }
    } catch (e) {
      throw Exception("Invalid max_length: ${variableOptions['max_length']}");
    }
  }

  return title;
}
