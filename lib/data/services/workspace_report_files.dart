import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'workspace_report.dart';

enum WorkspaceReportFormat {
  csv('CSV', 'csv'),
  excel('Excel', 'xlsx'),
  pdf('PDF', 'pdf'),
  word('Word', 'docx');

  final String label;
  final String extension;
  const WorkspaceReportFormat(this.label, this.extension);
}

class WorkspaceReportFiles {
  static Future<Uint8List> generate(
    List<ReportTable> tables,
    WorkspaceReportFormat format,
  ) async =>
      switch (format) {
        WorkspaceReportFormat.csv => _csv(tables),
        WorkspaceReportFormat.excel => _excel(tables),
        WorkspaceReportFormat.pdf => await _pdf(tables),
        WorkspaceReportFormat.word => _word(tables),
      };

  static String _display(Object value, String heading) =>
      value is num && heading.endsWith('(AED)')
          ? value.toStringAsFixed(2)
          : value.toString();

  static Uint8List _csv(List<ReportTable> tables) {
    // A single rectangular CSV, with the category in the first column.
    final columns = {for (final table in tables) ...table.headings}.toList();
    String escape(Object value, String heading) {
      var text = _display(value, heading);
      if (value is String &&
          RegExp(r'^[\s\x00-\x1f]*[=+\-@]|^[\t\r\n]').hasMatch(text)) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    final output = StringBuffer('\uFEFF')
      ..write(
          ['Category', ...columns].map((item) => escape(item, '')).join(','))
      ..write('\r\n');
    for (final table in tables) {
      for (final values in table.rows) {
        final row = Map.fromIterables(table.headings, values);
        output
          ..write(escape(table.title, ''))
          ..write(',')
          ..write(columns
              .map((column) => escape(row[column] ?? '', column))
              .join(','))
          ..write('\r\n');
      }
    }
    return Uint8List.fromList(utf8.encode(output.toString()));
  }

  static Future<Uint8List> _pdf(List<ReportTable> tables) async {
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final document = pw.Document(title: 'Workspace data report');
    for (final table in tables) {
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        maxPages: 100000,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text('Workspace data report  /  ${table.title}',
              style: const pw.TextStyle(
                  fontSize: 16, color: PdfColors.blueGrey800)),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9)),
        ),
        build: (_) => [
          if (table.rows.isEmpty) pw.Text('No records'),
          if (table.rows.isNotEmpty)
            pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(145),
                1: pw.FlexColumnWidth()
              },
              children: [
                for (final (index, row) in table.rows.indexed) ...[
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.blueGrey100),
                    children: [_pdfCell('Record ${index + 1}'), _pdfCell('')],
                  ),
                  for (final (column, value) in row.indexed)
                    if (value != '')
                      for (final (line, part)
                          in _chunks(_display(value, table.headings[column]))
                              .indexed)
                        pw.TableRow(children: [
                          _pdfCell(line == 0 ? table.headings[column] : ''),
                          _pdfCell(part),
                        ]),
                ],
              ],
            ),
        ],
      ));
    }
    return document.save();
  }

  static Iterable<String> _chunks(String text) sync* {
    // Keep any individual table row comfortably within one PDF page.
    final runes = text.runes.toList();
    for (var i = 0; i < runes.length; i += 180) {
      yield String.fromCharCodes(runes, i, math.min(i + 180, runes.length));
    }
  }

  static pw.Widget _pdfCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
      );

  static const _declaration =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  static const _officeRelationships =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _packageRelationships =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _spreadsheet =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _wordprocessing =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  static String _xml(String text) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert(text.replaceAll(
          RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]'), ''));

  static String _relations(String inner) =>
      '<Relationships xmlns="$_packageRelationships">$inner</Relationships>';

  static String _rootRelationship(String target) => _relations(
        '<Relationship Id="rId1" Type="$_officeRelationships/officeDocument" Target="$target"/>',
      );

  static String _types(String overrides) =>
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '$overrides</Types>';

  static String _part(String path, String type) =>
      '<Override PartName="/$path" ContentType="application/vnd.openxmlformats-officedocument.$type+xml"/>';

  static Uint8List _package(Map<String, String> parts) {
    final archive = Archive();
    for (final entry in parts.entries) {
      final data = utf8.encode('$_declaration${entry.value}');
      archive.addFile(ArchiveFile(entry.key, data.length, data));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static String _column(int index) {
    var result = '';
    for (var number = index + 1; number > 0; number = (number - 1) ~/ 26) {
      result = String.fromCharCode(65 + (number - 1) % 26) + result;
    }
    return result;
  }

  static Uint8List _excel(List<ReportTable> tables) {
    final files = <String, String>{};
    final entries = StringBuffer();
    final relations = StringBuffer();
    final types = StringBuffer()
      ..write(_part('xl/workbook.xml', 'spreadsheetml.sheet.main'))
      ..write(_part('xl/styles.xml', 'spreadsheetml.styles'));
    for (final (index, table) in tables.indexed) {
      final id = index + 1;
      final path = 'worksheets/sheet$id.xml';
      entries.write(
          '<sheet name="${_xml(table.title)}" sheetId="$id" r:id="rId$id"/>');
      relations.write(
          '<Relationship Id="rId$id" Type="$_officeRelationships/worksheet" Target="$path"/>');
      types.write(_part('xl/$path', 'spreadsheetml.worksheet'));
      files['xl/$path'] = _excelSheet(table);
    }
    relations.write(
        '<Relationship Id="styles" Type="$_officeRelationships/styles" Target="styles.xml"/>');
    return _package({
      '[Content_Types].xml': _types(types.toString()),
      '_rels/.rels': _rootRelationship('xl/workbook.xml'),
      'xl/workbook.xml':
          '<workbook xmlns="$_spreadsheet" xmlns:r="$_officeRelationships">'
              '<bookViews><workbookView/></bookViews>'
              '<sheets>$entries</sheets></workbook>',
      'xl/_rels/workbook.xml.rels': _relations(relations.toString()),
      'xl/styles.xml': '<styleSheet xmlns="$_spreadsheet">'
          '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
          '<font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Calibri"/></font></fonts>'
          '<fills count="3"><fill><patternFill patternType="none"/></fill>'
          '<fill><patternFill patternType="gray125"/></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="FF25465C"/><bgColor indexed="64"/></patternFill></fill></fills>'
          '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
          '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
          '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
          '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
          '<xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>'
          '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
          '</styleSheet>',
      ...files,
    });
  }

  static String _excelSheet(ReportTable table) {
    final matrix = [table.headings, ...table.rows];
    final widths = List<int>.filled(table.headings.length, 12);
    final data = StringBuffer();
    for (final (index, row) in matrix.indexed) {
      final rowNumber = index + 1;
      data.write('<row r="$rowNumber">');
      for (final (column, value) in row.indexed) {
        final heading = table.headings[column];
        final cell = '${_column(column)}$rowNumber';
        final display = _display(value, heading);
        widths[column] =
            math.max(widths[column], math.min(display.length + 3, 50));
        if (value is num && value.isFinite) {
          final style = heading.endsWith('(AED)') ? ' s="2"' : '';
          data.write('<c r="$cell"$style><v>$value</v></c>');
        } else {
          final style = index == 0 ? ' s="1"' : '';
          data.write(
              '<c r="$cell"$style t="inlineStr"><is><t xml:space="preserve">${_xml(display)}</t></is></c>');
        }
      }
      data.write('</row>');
    }
    final columns = StringBuffer();
    for (final (index, width) in widths.indexed) {
      final column = index + 1;
      columns.write(
          '<col min="$column" max="$column" width="$width" customWidth="1"/>');
    }
    final range = 'A1:${_column(widths.length - 1)}${matrix.length}';
    return '<worksheet xmlns="$_spreadsheet"><dimension ref="$range"/>'
        '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
        '<cols>$columns</cols><sheetData>$data</sheetData><autoFilter ref="$range"/></worksheet>';
  }

  static Uint8List _word(List<ReportTable> tables) {
    final body = StringBuffer();
    String run(String text, {bool bold = false, int size = 22}) =>
        '<w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:sz w:val="$size"/></w:rPr>'
        '${text.split('\n').map((line) => '<w:t xml:space="preserve">${_xml(line)}</w:t>').join('<w:br/>')}</w:r>';
    body.write(
        '<w:p>${run('Workspace data report', bold: true, size: 40)}</w:p>');
    for (final table in tables) {
      body.write(
          '<w:p><w:pPr><w:keepNext/><w:spacing w:before="300" w:after="100"/>'
          '<w:outlineLvl w:val="0"/></w:pPr>${run(table.title, bold: true, size: 30)}</w:p>');
      if (table.rows.isEmpty) body.write('<w:p>${run('No records')}</w:p>');
      for (final (index, row) in table.rows.indexed) {
        body.write(
            '<w:p><w:pPr><w:keepNext/><w:spacing w:before="160"/></w:pPr>'
            '${run('Record ${index + 1}', bold: true)}</w:p>');
        for (final (column, value) in row.indexed) {
          if (value == '') continue;
          final heading = table.headings[column];
          body.write('<w:p><w:pPr><w:spacing w:after="40"/></w:pPr>'
              '${run('$heading  ', bold: true)}${run(_display(value, heading))}</w:p>');
        }
      }
    }
    return _package({
      '[Content_Types].xml':
          _types(_part('word/document.xml', 'wordprocessingml.document.main')),
      '_rels/.rels': _rootRelationship('word/document.xml'),
      'word/document.xml': '<w:document xmlns:w="$_wordprocessing"><w:body>$body'
          '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" '
          'w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>'
          '</w:body></w:document>',
    });
  }
}
