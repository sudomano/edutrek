import 'dart:io';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/admin/login_screen.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/reusable_codes/logout_confirmations/logout_confirmation.dart';

class WelcomePage extends StatelessWidget {
  final List<String> quotes = [
    "Education is the passport to the future, for tomorrow belongs to those who prepare for it today. – Malcolm X",
    "Effective school management is the key to unlocking success.",
    "A well-managed school is a foundation for academic excellence.",
    "The best school managers are those who inspire and lead by example.",
    "Leadership in education is about creating a culture of learning.",
    "Good management transforms schools into thriving learning communities.",
    "'Education is the most powerful weapon you can use to change the world.' Nelson Mandela",
    "Effective leadership in education starts with a vision and ends with student success. – Anonymous",
    "The best schools are those where learning is valued above all else. – Anonymous",
    "Leaders who listen create schools that thrive. – Peter Drucker",
    "Effective management turns challenges into opportunities. – Donald Trump",
    "A well-managed school builds confident learners. – Anonymous",
    "Consistency in management fosters stability and progress. – Jack Welch",
    "True leadership is about empowering others to lead. – Bill Gates",
    "Great leaders in education inspire lifelong learning. – Ken Robinson",
    "School management is the art of creating an environment for growth. – Abraham Lincoln",
    "A school is only as strong as its leadership. – John C. Maxwell",
    "Teachers flourish under supportive leadership. – Robert John Meehan",
    "Good school leaders never stop learning themselves. – Andy Hargreaves",
    "Visionary leaders are the architects of tomorrow’s schools. – Stephen Covey",
    "Effective management focuses on outcomes, not obstacles. – Brian Tracy",
    "Strong leadership builds strong communities. – Anonymous",
    "Success in school management is about adaptability and foresight. – John Wooden",
    "Every decision in a school should put students first. – Haim G. Ginott",
    "Leaders set the tone, but it's teamwork that achieves success. – Anonymous",
    "In education, leading by example is the most powerful form of teaching. – Albert Schweitzer"
        "A leader’s job is not to do all the work, but to create the conditions for others to succeed. – Simon Sinek",
    "Great schools are built on a foundation of trust and collaboration. – Brene Brown",
    "True leaders help others rise to their full potential. – John Quincy Adams",
    "Leadership is not a position; it’s an action. – Donald H. McGannon",
    "Effective school management creates pathways for innovation. – Peter Senge",
    "Successful schools have leaders who listen to the voices of their students. – Anonymous",
    "The purpose of education is to replace an empty mind with an open one. – Malcolm Forbes",
    "A well-managed school is a happy school. – Anonymous",
    "Good leaders inspire others to have confidence in them; great leaders inspire others to have confidence in themselves. – Eleanor Roosevelt",
    "Strong schools build strong futures. – Anonymous",
    "An effective school is one where every learner feels valued. – Anonymous",
    "Leadership in education requires humility and courage. – Andy Stanley",
    "Great leaders build a legacy that others can follow. – John C. Maxwell",
    "Strong leadership empowers teachers to innovate and inspire. – Anonymous",
    "Schools flourish when everyone feels they belong. – Maya Angelou",
    "Education is not the filling of a pail, but the lighting of a fire. – William Butler Yeats",
    "In a well-managed school, every student is given the chance to shine. – Robert John Meehan",
    "Leadership is the capacity to translate vision into reality. – Warren Bennis",
    "A school’s success is measured by the growth of its students. – Anonymous",
    "Good leadership in schools creates a culture of respect and responsibility. – Anonymous",
    "Effective school leaders create a shared vision for success. – Andy Hargreaves",
    "Innovation in education begins with strong leadership. – Steve Jobs",
    "Good management helps schools adapt to a changing world. – Anonymous",
    "Leadership is about making others better as a result of your presence. – Sheryl Sandberg",
    "Effective management is about turning plans into action. – Anonymous",
    "A strong school leader helps every student and teacher succeed. – Anonymous",
    "Great leaders cultivate a spirit of collaboration and inclusiveness. – Patrick Lencioni",
    "Empowered teachers create empowered learners. – Robert John Meehan",
    "Leadership in education is about shaping futures, not just managing the present. – Ken Robinson",
    "A school led by compassion grows in strength and character. – Anonymous",
    "Leaders who encourage risk-taking create innovators in the classroom. – Richard Branson",
    "Good school management inspires trust, accountability, and excellence. – Anonymous",
    "Education is a shared responsibility between leaders, teachers, and learners. – Haim G. Ginott",
    "Effective school leadership is about creating possibilities. – George Couros",
    "Schools thrive when their leaders prioritize student well-being. – Anonymous",
    "True leadership is about helping others reach their potential. – John C. Maxwell",
    "A good school leader makes everyone feel valued and heard. – Patrick Lencioni",
    "Effective leadership fosters a culture of continuous improvement. – Peter Senge",
    "A school leader’s greatest success lies in the success of others. – Zig Ziglar",
    "Leadership is not just about making the right decisions but empowering others to make them too. – Brene Brown",
    "Strong schools are built by leaders who foster a sense of community. – Anonymous",
    "Good leadership in schools turns visions into achievements. – Stephen Covey",
    "An effective leader is one who serves rather than commands. – Lao Tzu",
    "The future of education rests in the hands of great leaders. – Andy Hargreaves",
    "Schools thrive when their leaders are committed to learning as much as their students. – Anonymous",
    "Effective school leaders make time for innovation. – Steve Jobs",
    "Leadership in education is about creating opportunities for all students. – Nelson Mandela",
    "A school led with empathy and understanding is a school that succeeds. – Maya Angelou",
    "In education, management is about more than rules; it's about relationships. – Simon Sinek",
    "Leadership means showing others the way, not just telling them where to go. – John C. Maxwell",
    "Effective management nurtures the talents of both teachers and students. – Anonymous",
    "A leader’s vision gives a school its direction. – Warren Bennis",
    "Success in education begins with a strong foundation of leadership. – Patrick Lencioni",
    "Great leaders in education are those who bring out the best in others. – John Quincy Adams",
    "Schools that invest in leadership create learners for life. – Anonymous",
    "True leadership is about building the next generation of leaders. – Nelson Mandela",
    "The best leaders know when to listen, learn, and adapt. – Anonymous",
    "Effective leadership creates a school where everyone is a learner. – Andy Hargreaves",
    "In education, good management is about creating the conditions for learning. – Ken Robinson",
    "Great school leaders know that education is the key to unlocking a student’s potential. – Anonymous",
    "A leader’s greatest achievement is the success of others. – Simon Sinek",
    "In education, leadership is about making meaningful connections. – Nelson Mandela",
    "Good leadership in schools encourages creativity, collaboration, and curiosity. – Ken Robinson",
    "The best school leaders build cultures of respect, trust, and responsibility. – Patrick Lencioni",
    "Effective school management is about creating a space where learning thrives. – Anonymous",
    "Leadership in education starts with a vision and ends with student success. – Peter Drucker",
    "A well-managed school makes space for every voice to be heard. – Anonymous",
    "True leadership in education is about making a difference, not just making decisions. – Brene Brown",
    "Education opens the door to the future, but strong leadership keeps it open. – John C. Maxwell",
    "A successful school is led by those who care deeply about their students. – Anonymous",
    "Leaders in education create pathways for growth, not just policies. – Andy Hargreaves",
    "Good leadership creates an environment where learning is an adventure. – Anonymous",
    "The best school leaders are those who inspire others to dream, learn, and achieve. – Maya Angelou",
    "Great schools are built on a foundation of trust and shared values. – Anonymous",
    "Leadership in education is about fostering resilience and creativity in students. – Nelson Mandela",
    "In a well-led school, every student believes they can succeed. – Robert John Meehan",
    "A great school leader knows that every child has the potential to achieve greatness. – John Dewey",
  ];
  Future<List<School>> fetchSchools() async {
    var box = await Hive.openBox<School>('school');
    return box.values.where((schoolItem) => schoolItem.termId != null).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Home',
            style: TextStyle(
              fontSize: 14.0, // Adjust font size
              fontWeight: FontWeight.normal, // Font weight
              color: Colors.white, // Title color
              letterSpacing: 1.2, // Slight letter spacing for elegance
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app,
                color: Color.fromARGB(255, 255, 255, 255)),
            onPressed: () {
              showLogoutConfirmationDialog(context);
            },
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0, // Subtle shadow
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.lightBlueAccent, Colors.blue],
              ),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),

                    FutureBuilder<List<School>>(
                      future: fetchSchools(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text(
                            "No  Schools Yet",
                            style: TextStyle(color: Colors.red),
                          );
                        } else if (snapshot.hasData) {
                          return Column(
                            children: snapshot.data!.map((schoolItem) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: schoolItem.schoolLogoPath != null
                                    ? Image.file(
                                        File(schoolItem.schoolLogoPath!),
                                        width: 400,
                                        height: 250,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                              );
                            }).toList(),
                          );
                        } else {
                          return const Text("No schools available");
                        }
                      },
                    ),

                    // Logo or branding
                    // Welcoming Note
                    FutureBuilder<List<School>>(
                      future: fetchSchools(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text(
                            "Error fetching school data",
                            style: TextStyle(color: Colors.red),
                          );
                        } else if (snapshot.hasData &&
                            snapshot.data!.isNotEmpty) {
                          final schoolItem = snapshot
                              .data!.first; // Use the first school for display
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              '${schoolItem.schoolName} School Management System',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    offset: Offset(2, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Welcome to the School Management System',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    offset: Offset(2, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Sliding Quotes
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 200,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 2),
                        enlargeCenterPage: true,
                        scrollDirection: Axis.horizontal,
                        enableInfiniteScroll: true,
                        aspectRatio: 16 / 9,
                      ),
                      items: quotes.map((quote) {
                        return Builder(
                          builder: (BuildContext context) {
                            return Container(
                              width: MediaQuery.of(context).size.width,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 5.0),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    quote,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue[900],
                                      shadows: const [
                                        Shadow(
                                          color: Colors.grey,
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Carousel Arrows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white),
                          onPressed: () {
                            // Backward functionality
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white),
                          onPressed: () {
                            // Forward functionality
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Dashboard Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blue[800],
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 10,
                      ),
                      child: Text(
                        'Go to Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
