import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import '../database/student.dart';

class ViewStudentsScreen extends StatelessWidget {
  const ViewStudentsScreen({super.key});
  String capitalize(String value) {
    var result = value[0].toUpperCase();
    for (int i = 1; i < value.length; i++) {
      if (value[i - 1] == " ") {
        result = result + value[i].toUpperCase();
      } else {
        result = result + value[i];
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text('View Students')),
        backgroundColor:
            Color.fromARGB(255, 248, 249, 249), // Set app bar background color
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(253, 254, 254, 1),
              Color.fromRGBO(241, 242, 242, 1)
            ], // Gradient background colors
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Student>>(
          future: Hive.openBox<Student>('students').then((box) {
            var students = box.values
                .where((classItem) => classItem.termId == globalTermId)
                .toList();
            students.sort((a, b) => a.surname.compareTo(b.surname));
            return students;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.hasData) {
              final List<Student> students = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final fontSize = maxWidth < 600
                      ? 12.0
                      : 14.0; // Adjust font size based on device width

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowHeight: 60,
                      columns: [
                        DataColumn(
                            label: Text('Name',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Surname',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Registration Number',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Class',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Gender',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Date of Birth',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Parent Phone Number',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Parent Name',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('School Term',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Health Status',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Health Detailed Information',
                                style: TextStyle(fontSize: fontSize))),
                      ],
                      rows: students.map((student) {
                        return DataRow(cells: [
                          DataCell(Text(capitalize(student.name),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(student.surname),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(student.regNumber,
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(student.class_),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(student.gender),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(student.age.toString(),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(student.phoneNumber,
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(student.paymentStatus),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(student.termId.toString()),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(
                              capitalize(student.healthStauts.toString()),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(
                              capitalize(
                                  student.healthDetailedInformation.toString()),
                              style: TextStyle(fontSize: fontSize))),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              );
            } else {
              return const Center(
                child: Text('No students found.'),
              );
            }
          },
        ),
      ),
    );
  }
}
