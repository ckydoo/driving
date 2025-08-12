import 'package:driving/widgets/responsive_card_layout.dart';
import 'package:driving/widgets/responsive_extensions.dart';
import 'package:driving/widgets/responsive_text.dart';
import 'package:flutter/material.dart';

class ResponsiveDataTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final List<VoidCallback>? rowCallbacks;
  final bool sortAscending;
  final int? sortColumnIndex;

  const ResponsiveDataTable({
    Key? key,
    required this.headers,
    required this.rows,
    this.rowCallbacks,
    this.sortAscending = true,
    this.sortColumnIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileList(context);
    } else {
      return _buildDataTable(context);
    }
  }

  Widget _buildMobileList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return ResponsiveCard(
          child: InkWell(
            onTap: rowCallbacks?[index],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                headers.length.clamp(0, row.length),
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: ResponsiveText(
                          headers[i],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      Expanded(
                        child: ResponsiveText(
                          row[i],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortAscending: sortAscending,
        sortColumnIndex: sortColumnIndex,
        headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
        columns: headers.map((header) {
          return DataColumn(
            label: ResponsiveText(
              header,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
        rows: List.generate(rows.length, (index) {
          final row = rows[index];
          return DataRow(
            onSelectChanged:
                rowCallbacks != null ? (_) => rowCallbacks![index]() : null,
            cells: row.map((cell) {
              return DataCell(ResponsiveText(cell, fontSize: 13));
            }).toList(),
          );
        }),
      ),
    );
  }
}
