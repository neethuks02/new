enum ExecutiveRole { field, office }

class Executive {
  final String id;
  final String name;
  final ExecutiveRole role;
  final String phone;
  final String email;
  final int activeLeadsCount;
  final double performanceScore;

  Executive({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.activeLeadsCount,
    required this.performanceScore,
  });
}

class TimelineEvent {
  final String title;
  final String description;
  final DateTime date;
  final bool isCompleted;

  TimelineEvent({
    required this.title,
    required this.description,
    required this.date,
    required this.isCompleted,
  });
}

class Lead {
  final String id;
  // Step 1: Student Details
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String address;

  // Step 2: Agency Details
  final String agencyName;
  final String branchLocation;
  final String counselorName;

  // Step 3: Placement Details
  final String program;
  final String country;
  final String institution;
  final String intake;

  // Step 4: Pricing
  final double totalAmount;
  final double advanceAmount;
  final double agencyCommission;

  // Step 5: Documents (simplified as a list of names)
  final List<String> documents;

  // Management details
  final String status;
  final Executive? assignedExecutive;
  final DateTime createdAt;
  final List<TimelineEvent> timeline;

  Lead({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.address,
    required this.agencyName,
    required this.branchLocation,
    required this.counselorName,
    required this.program,
    required this.country,
    required this.institution,
    required this.intake,
    required this.totalAmount,
    required this.advanceAmount,
    required this.agencyCommission,
    required this.documents,
    required this.status,
    this.assignedExecutive,
    required this.createdAt,
    required this.timeline,
  });

  String get studentName => '$firstName $lastName';
}

class MockData {
  static final List<Executive> executives = [
    Executive(
      id: 'E001',
      name: 'Sarah Jenkins',
      role: ExecutiveRole.field,
      phone: '+1 234 567 8900',
      email: 'sarah.j@agency.com',
      activeLeadsCount: 12,
      performanceScore: 92.5,
    ),
    Executive(
      id: 'E002',
      name: 'Michael Chen',
      role: ExecutiveRole.office,
      phone: '+1 234 567 8901',
      email: 'michael.c@agency.com',
      activeLeadsCount: 28,
      performanceScore: 88.0,
    ),
    Executive(
      id: 'E003',
      name: 'Emma Watson',
      role: ExecutiveRole.field,
      phone: '+1 234 567 8902',
      email: 'emma.w@agency.com',
      activeLeadsCount: 15,
      performanceScore: 95.0,
    ),
  ];

  static final List<Lead> leads = [
    Lead(
      id: 'L1001',
      firstName: 'Alex',
      lastName: 'Johnson',
      phone: '+1 555 123 4567',
      email: 'alex.j@example.com',
      address: '123 Tech Lane, Silicon Valley, CA',
      agencyName: 'Global Ed Consultants',
      branchLocation: 'San Francisco',
      counselorName: 'Jane Doe',
      program: 'MSc Computer Science',
      country: 'United Kingdom',
      institution: 'University of Oxford',
      intake: 'Fall 2026',
      totalAmount: 15000,
      advanceAmount: 2000,
      agencyCommission: 1500,
      documents: ['Passport.pdf', 'Transcripts_BSc.pdf'],
      status: 'In Progress',
      assignedExecutive: executives[0],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added to the system',
          date: DateTime.now().subtract(const Duration(days: 2)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Sarah Jenkins',
          description: 'Assigned by Manager',
          date: DateTime.now().subtract(const Duration(days: 1)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Documents Verified',
          description: 'Waiting for university approval',
          date: DateTime.now(),
          isCompleted: false,
        ),
      ],
    ),
    Lead(
      id: 'L1002',
      firstName: 'Priya',
      lastName: 'Sharma',
      phone: '+1 555 987 6543',
      email: 'priya.s@example.com',
      address: '45 Gandhi Road, New Delhi',
      agencyName: 'Future Pathways',
      branchLocation: 'Delhi',
      counselorName: 'Rahul Verma',
      program: 'MBA',
      country: 'Canada',
      institution: 'University of Toronto',
      intake: 'Fall 2026',
      totalAmount: 25000,
      advanceAmount: 5000,
      agencyCommission: 2500,
      documents: ['Passport.pdf', 'IELTS_Score.pdf'],
      status: 'New',
      assignedExecutive: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added via portal',
          date: DateTime.now().subtract(const Duration(hours: 5)),
          isCompleted: true,
        ),
      ],
    ),
    Lead(
      id: 'L1003',
      firstName: 'Wei',
      lastName: 'Chen',
      phone: '+86 138 0013 8000',
      email: 'wei.chen@example.com',
      address: '88 Tech Park, Beijing, China',
      agencyName: 'Oriental Education',
      branchLocation: 'Beijing',
      counselorName: 'Li Wei',
      program: 'BEng Mechanical Engineering',
      country: 'USA',
      institution: 'MIT',
      intake: 'Fall 2026',
      totalAmount: 45000,
      advanceAmount: 10000,
      agencyCommission: 4500,
      documents: ['Passport.pdf', 'HighSchool_Transcript.pdf', 'TOEFL.pdf'],
      status: 'Completed',
      assignedExecutive: executives[1], // Michael Chen
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added',
          date: DateTime.now().subtract(const Duration(days: 45)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Michael Chen',
          description: 'Assigned by Manager',
          date: DateTime.now().subtract(const Duration(days: 44)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'University Accepted',
          description: 'Offer letter received from MIT',
          date: DateTime.now().subtract(const Duration(days: 10)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Visa Approved',
          description: 'Student Visa granted',
          date: DateTime.now().subtract(const Duration(days: 2)),
          isCompleted: true,
        ),
      ],
    ),
    Lead(
      id: 'L1004',
      firstName: 'Maria',
      lastName: 'Garcia',
      phone: '+34 600 123 456',
      email: 'maria.g@example.com',
      address: '10 Gran Via, Madrid, Spain',
      agencyName: 'Europa Study',
      branchLocation: 'Madrid',
      counselorName: 'Carlos Ruiz',
      program: 'MSc Data Science',
      country: 'Australia',
      institution: 'University of Melbourne',
      intake: 'Spring 2026',
      totalAmount: 22000,
      advanceAmount: 3000,
      agencyCommission: 2200,
      documents: ['Passport.pdf'],
      status: 'In Progress',
      assignedExecutive: executives[2], // Emma Watson
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added',
          date: DateTime.now().subtract(const Duration(days: 10)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Emma Watson',
          description: 'Assigned by Manager',
          date: DateTime.now().subtract(const Duration(days: 9)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Application Submitted',
          description: 'Sent to University of Melbourne',
          date: DateTime.now().subtract(const Duration(days: 5)),
          isCompleted: true,
        ),
      ],
    ),
    Lead(
      id: 'L1005',
      firstName: 'Ahmed',
      lastName: 'Hassan',
      phone: '+971 50 123 4567',
      email: 'ahmed.h@example.com',
      address: 'Dubai Marina, Dubai, UAE',
      agencyName: 'Gulf Education',
      branchLocation: 'Dubai',
      counselorName: 'Fatima Ali',
      program: 'BSc Business Administration',
      country: 'Canada',
      institution: 'University of British Columbia',
      intake: 'Fall 2026',
      totalAmount: 18000,
      advanceAmount: 2000,
      agencyCommission: 1800,
      documents: ['Passport.pdf', 'HighSchool_Transcript.pdf'],
      status: 'New',
      assignedExecutive: executives[0], // Sarah Jenkins
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added',
          date: DateTime.now().subtract(const Duration(hours: 1)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Sarah Jenkins',
          description: 'Assigned by auto-routing',
          date: DateTime.now().subtract(const Duration(minutes: 55)),
          isCompleted: true,
        ),
      ],
    ),
    Lead(
      id: 'L1003',
      firstName: 'Wei',
      lastName: 'Chen',
      phone: '+86 138 0013 8000',
      email: 'wei.chen@example.com',
      address: '88 Tech Park, Beijing, China',
      agencyName: 'Oriental Education',
      branchLocation: 'Beijing',
      counselorName: 'Li Wei',
      program: 'BEng Mechanical Engineering',
      country: 'USA',
      institution: 'MIT',
      intake: 'Fall 2026',
      totalAmount: 45000,
      advanceAmount: 10000,
      agencyCommission: 4500,
      documents: ['Passport.pdf', 'HighSchool_Transcript.pdf', 'TOEFL.pdf'],
      status: 'Completed',
      assignedExecutive: executives[1], // Michael Chen
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added',
          date: DateTime.now().subtract(const Duration(days: 45)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Michael Chen',
          description: 'Assigned by Manager',
          date: DateTime.now().subtract(const Duration(days: 44)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'University Accepted',
          description: 'Offer letter received from MIT',
          date: DateTime.now().subtract(const Duration(days: 10)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Visa Approved',
          description: 'Student Visa granted',
          date: DateTime.now().subtract(const Duration(days: 2)),
          isCompleted: true,
        ),
      ],
    ),
    Lead(
      id: 'L1004',
      firstName: 'Maria',
      lastName: 'Garcia',
      phone: '+34 600 123 456',
      email: 'maria.g@example.com',
      address: '10 Gran Via, Madrid, Spain',
      agencyName: 'Europa Study',
      branchLocation: 'Madrid',
      counselorName: 'Carlos Ruiz',
      program: 'MSc Data Science',
      country: 'Australia',
      institution: 'University of Melbourne',
      intake: 'Spring 2026',
      totalAmount: 22000,
      advanceAmount: 3000,
      agencyCommission: 2200,
      documents: ['Passport.pdf'],
      status: 'In Progress',
      assignedExecutive: executives[2], // Emma Watson
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added',
          date: DateTime.now().subtract(const Duration(days: 10)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Emma Watson',
          description: 'Assigned by Manager',
          date: DateTime.now().subtract(const Duration(days: 9)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Application Submitted',
          description: 'Sent to University of Melbourne',
          date: DateTime.now().subtract(const Duration(days: 5)),
          isCompleted: true,
        ),
      ],
    ),
    Lead(
      id: 'L1005',
      firstName: 'Ahmed',
      lastName: 'Hassan',
      phone: '+971 50 123 4567',
      email: 'ahmed.h@example.com',
      address: 'Dubai Marina, Dubai, UAE',
      agencyName: 'Gulf Education',
      branchLocation: 'Dubai',
      counselorName: 'Fatima Ali',
      program: 'BSc Business Administration',
      country: 'Canada',
      institution: 'University of British Columbia',
      intake: 'Fall 2026',
      totalAmount: 18000,
      advanceAmount: 2000,
      agencyCommission: 1800,
      documents: ['Passport.pdf', 'HighSchool_Transcript.pdf'],
      status: 'New',
      assignedExecutive: executives[0], // Sarah Jenkins
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      timeline: [
        TimelineEvent(
          title: 'Lead Created',
          description: 'Lead was added',
          date: DateTime.now().subtract(const Duration(hours: 1)),
          isCompleted: true,
        ),
        TimelineEvent(
          title: 'Assigned to Sarah Jenkins',
          description: 'Assigned by auto-routing',
          date: DateTime.now().subtract(const Duration(minutes: 55)),
          isCompleted: true,
        ),
      ],
    ),

    Lead(
      id: 'L1006',
      firstName: 'Daniel', lastName: 'Kim',
      phone: '+82 10 1234 5678', email: 'daniel.k@example.com',
      address: 'Seoul, South Korea',
      agencyName: 'EduKorea', branchLocation: 'Seoul', counselorName: 'Ji-hoon',
      program: 'MSc Marketing', country: 'United Kingdom', institution: 'Kings College London',
      intake: 'Fall 2026', totalAmount: 25000, advanceAmount: 5000, agencyCommission: 2500,
      documents: ['Passport.pdf'], status: 'New', assignedExecutive: executives[0],
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      timeline: [],
    ),
    Lead(
      id: 'L1007',
      firstName: 'Priya', lastName: 'Patel',
      phone: '+91 98765 43210', email: 'priya.p@example.com',
      address: 'Mumbai, India',
      agencyName: 'Global Reach', branchLocation: 'Mumbai', counselorName: 'Rahul',
      program: 'MBA', country: 'Canada', institution: 'Rotman School of Management',
      intake: 'Spring 2027', totalAmount: 55000, advanceAmount: 10000, agencyCommission: 5500,
      documents: ['Passport.pdf', 'GMAT.pdf'], status: 'In Progress', assignedExecutive: executives[1],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      timeline: [],
    ),
    Lead(
      id: 'L1008',
      firstName: 'Oliver', lastName: 'Smith',
      phone: '+44 7700 900000', email: 'oliver.s@example.com',
      address: 'London, UK',
      agencyName: 'Study Abroad UK', branchLocation: 'London', counselorName: 'Emma',
      program: 'BSc Economics', country: 'USA', institution: 'NYU',
      intake: 'Fall 2026', totalAmount: 60000, advanceAmount: 15000, agencyCommission: 6000,
      documents: ['Passport.pdf'], status: 'New', assignedExecutive: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      timeline: [],
    ),
    Lead(
      id: 'L1009',
      firstName: 'Sophia', lastName: 'Martinez',
      phone: '+52 55 1234 5678', email: 'sophia.m@example.com',
      address: 'Mexico City, Mexico',
      agencyName: 'Estudios Globales', branchLocation: 'Mexico City', counselorName: 'Carlos',
      program: 'MSc Artificial Intelligence', country: 'Canada', institution: 'University of Toronto',
      intake: 'Fall 2026', totalAmount: 30000, advanceAmount: 5000, agencyCommission: 3000,
      documents: ['Passport.pdf', 'Transcripts.pdf'], status: 'Completed', assignedExecutive: executives[2],
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      timeline: [],
    ),
    Lead(
      id: 'L1010',
      firstName: 'Lucas', lastName: 'Silva',
      phone: '+55 11 98765 4321', email: 'lucas.s@example.com',
      address: 'Sao Paulo, Brazil',
      agencyName: 'Intercambio Brazil', branchLocation: 'Sao Paulo', counselorName: 'Ana',
      program: 'BA Design', country: 'Australia', institution: 'RMIT',
      intake: 'Spring 2027', totalAmount: 20000, advanceAmount: 4000, agencyCommission: 2000,
      documents: ['Portfolio.pdf'], status: 'In Progress', assignedExecutive: executives[0],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      timeline: [],
    ),
    Lead(
      id: 'L1011',
      firstName: 'Yuki', lastName: 'Tanaka',
      phone: '+81 90 1234 5678', email: 'yuki.t@example.com',
      address: 'Tokyo, Japan',
      agencyName: 'Japan Edu', branchLocation: 'Tokyo', counselorName: 'Kenji',
      program: 'BSc Computer Science', country: 'USA', institution: 'Stanford',
      intake: 'Fall 2026', totalAmount: 65000, advanceAmount: 20000, agencyCommission: 6500,
      documents: ['Passport.pdf', 'SAT.pdf'], status: 'New', assignedExecutive: executives[1],
      createdAt: DateTime.now().subtract(const Duration(hours: 24)),
      timeline: [],
    ),
    Lead(
      id: 'L1012',
      firstName: 'Fatima', lastName: 'Zahra',
      phone: '+212 600 123 456', email: 'fatima.z@example.com',
      address: 'Casablanca, Morocco',
      agencyName: 'Edu Maroc', branchLocation: 'Casablanca', counselorName: 'Omar',
      program: 'MSc Finance', country: 'United Kingdom', institution: 'LSE',
      intake: 'Fall 2026', totalAmount: 35000, advanceAmount: 7000, agencyCommission: 3500,
      documents: ['Passport.pdf'], status: 'In Progress', assignedExecutive: executives[2],
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      timeline: [],
    ),

  ];
}
