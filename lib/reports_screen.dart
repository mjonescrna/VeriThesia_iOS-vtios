import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReportsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> entries;

  const ReportsScreen({super.key, required this.entries});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _filteredEntries = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Start with no entries displayed until a date range is selected.
    _filteredEntries = [];
  }

  /// Opens the date range picker and filters the entries.
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
      });
      _filterReports();
    }
  }

  /// Filters entries based on the selected date range.
  void _filterReports() {
    if (_selectedDateRange != null) {
      setState(() {
        _filteredEntries = widget.entries.where((entry) {
          try {
            final entryDate = DateFormat('MM/dd/yyyy').parse(entry['date']);
            return entryDate.isAfter(_selectedDateRange!.start
                    .subtract(const Duration(days: 1))) &&
                entryDate.isBefore(
                    _selectedDateRange!.end.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      });
    } else {
      // If no date range is selected, clear the filtered entries.
      setState(() {
        _filteredEntries = [];
      });
    }
  }

  /// Downloads the current filtered report as a CSV file.
  Future<void> _downloadReport() async {
    if (_filteredEntries.isEmpty) return;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Shift_Differential_Report.csv');

    String csvData = 'Date,Task,Hours,Total\n';
    for (var entry in _filteredEntries) {
      csvData +=
          '${entry['date']},${entry['task']},${entry['hours']},${entry['total']}\n';
    }

    await file.writeAsString(csvData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report downloaded to ${file.path}')),
    );
  }

  /// Calculates the total pay from all filtered entries.
  double _calculateTotalPay() {
    return _filteredEntries.fold(
      0,
      (sum, entry) => sum + (entry['total'] as double),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Display a message based on whether a date range has been selected.
    String emptyMessage;
    if (_selectedDateRange == null) {
      emptyMessage = 'Please select a date range to generate a report.';
    } else {
      emptyMessage = 'No report entries available for the selected range.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date range header and selector
            const Text(
              'Select Date Range',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDateRange(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDateRange == null
                          ? 'Please select a date range'
                          : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Clear Filter resets the date range and filtered entries.
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateRange = null;
                      _filteredEntries = [];
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text(
                    'Clear Filter',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: _downloadReport,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text(
                    'Download Report',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(),
            // Report list view
            Expanded(
              child: _filteredEntries.isEmpty
                  ? Center(
                      child: Text(
                        emptyMessage,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredEntries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          child: ListTile(
                            title: Text(
                              '${entry['task']} - ${entry['hours']} hrs',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Date: ${entry['date']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${(entry['total'] as double).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _filteredEntries.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_filteredEntries.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Total Shift Differential Pay:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${_calculateTotalPay().toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
