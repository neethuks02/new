import 'package:iconex_flutter/iconex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';

/*
// --- OLD UI COMMENTED OUT ---

class CreateLeadScreen extends StatefulWidget {
  final String? leadId;
  const CreateLeadScreen({super.key, this.leadId});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  Executive? _selectedExecutive;

  // Form Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  final _agencyNameController = TextEditingController();
  final _branchController = TextEditingController();
  final _counselorController = TextEditingController();

  final _courseController = TextEditingController();
  final _universityController = TextEditingController();
  final _intakeController = TextEditingController();

  final _totalAmountController = TextEditingController();
  final _advanceAmountController = TextEditingController();
  final _commissionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.leadId != null) {
      final lead = MockData.leads.firstWhere((l) => l.id == widget.leadId);
      _firstNameController.text = lead.firstName;
      _lastNameController.text = lead.lastName;
      _emailController.text = lead.email;
      _phoneController.text = lead.phone;
      _addressController.text = lead.address;
      
      _agencyNameController.text = lead.agencyName;
      _branchController.text = lead.branchLocation;
      _counselorController.text = lead.counselorName;

      _courseController.text = lead.program;
      _universityController.text = lead.institution;
      _intakeController.text = lead.intake;

      _totalAmountController.text = lead.totalAmount.toString();
      _advanceAmountController.text = lead.advanceAmount.toString();
      _commissionController.text = lead.agencyCommission.toString();
      _selectedExecutive = lead.assignedExecutive;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _agencyNameController.dispose();
    _branchController.dispose();
    _counselorController.dispose();
    _courseController.dispose();
    _universityController.dispose();
    _intakeController.dispose();
    _totalAmountController.dispose();
    _advanceAmountController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _showAssignmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign Executive', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Select an executive to handle this lead.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search executives...',
                      prefixIcon: Icon(Iconex.light.search),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      itemCount: MockData.executives.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final exec = MockData.executives[index];
                        final isSelected = _selectedExecutive?.id == exec.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Text(exec.name.substring(0, 1), style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(exec.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(exec.role.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                          trailing: isSelected ? Icon(Iconex.light.check, color: AppColors.primary) : null,
                          onTap: () {
                            setSheetState(() => _selectedExecutive = exec);
                            setState(() => _selectedExecutive = exec);
                            context.pop();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveLead() {
    if (widget.leadId != null) {
      final index = MockData.leads.indexWhere((l) => l.id == widget.leadId);
      if (index != -1) {
        final old = MockData.leads[index];
        MockData.leads[index] = Lead(
          id: old.id,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          address: _addressController.text,
          agencyName: _agencyNameController.text,
          branchLocation: _branchController.text,
          counselorName: _counselorController.text,
          program: _courseController.text,
          country: old.country,
          institution: _universityController.text,
          intake: _intakeController.text,
          totalAmount: double.tryParse(_totalAmountController.text) ?? old.totalAmount,
          advanceAmount: double.tryParse(_advanceAmountController.text) ?? old.advanceAmount,
          agencyCommission: double.tryParse(_commissionController.text) ?? old.agencyCommission,
          documents: old.documents,
          status: old.status,
          assignedExecutive: _selectedExecutive,
          createdAt: old.createdAt,
          timeline: old.timeline,
        );
      }
    }
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.leadId == null ? 'Lead created and assigned successfully!' : 'Lead updated successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.leadId == null ? 'Create New Lead' : 'Edit Lead', style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Iconex.light.close),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard('Student Details', _buildStudentDetails()),
                  const SizedBox(height: 20),
                  _buildSectionCard('Agency Details', _buildAgencyDetails()),
                  const SizedBox(height: 20),
                  _buildSectionCard('Placement Details', _buildPlacementDetails()),
                  const SizedBox(height: 20),
                  _buildSectionCard('Pricing', _buildPricingDetails()),
                  const SizedBox(height: 20),
                  _buildSectionCard('Assignment', _buildAssignmentSection()),
                  const SizedBox(height: 20),
                  _buildSectionCard('Documents', _buildDocumentsUpload()),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saveLead,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  widget.leadId == null ? 'Create Lead' : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, [TextInputType type = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7), size: 20),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildStudentDetails() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField('First Name', Iconex.light.user, _firstNameController)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('Last Name', Iconex.light.user, _lastNameController)),
          ],
        ),
        _buildTextField('Email Address', Iconex.light.mail, _emailController, TextInputType.emailAddress),
        _buildTextField('Phone Number', Iconex.light.call, _phoneController, TextInputType.phone),
        _buildTextField('Address', Iconex.light.location, _addressController),
      ],
    );
  }

  Widget _buildAgencyDetails() {
    return Column(
      children: [
        _buildTextField('Agency Name', Iconex.light.home, _agencyNameController),
        _buildTextField('Branch Location', Iconex.light.location, _branchController),
        _buildTextField('Counselor Name', Iconex.light.user, _counselorController),
      ],
    );
  }

  Widget _buildPlacementDetails() {
    return Column(
      children: [
        _buildTextField('Course (e.g. MSc)', Iconex.light.book, _courseController),
        _buildTextField('University / Institution', Iconex.light.home, _universityController),
        _buildTextField('Target Intake (e.g. Fall 2026)', Iconex.light.calendar, _intakeController),
      ],
    );
  }

  Widget _buildPricingDetails() {
    return Column(
      children: [
        _buildTextField('Total Amount', Iconex.light.wallet, _totalAmountController, TextInputType.number),
        _buildTextField('Advance Amount', Iconex.light.wallet, _advanceAmountController, TextInputType.number),
        _buildTextField('Agency Commission', Iconex.light.wallet, _commissionController, TextInputType.number),
      ],
    );
  }

  Widget _buildAssignmentSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _selectedExecutive != null ? AppColors.primaryLight : Colors.grey.shade200,
          child: Icon(Iconex.light.user, color: _selectedExecutive != null ? Colors.white : Colors.grey.shade400),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedExecutive?.name ?? 'Unassigned', 
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: _selectedExecutive != null ? AppColors.textPrimary : AppColors.textSecondary)
              ),
              if (_selectedExecutive != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(_selectedExecutive!.role.name.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: _showAssignmentBottomSheet,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(_selectedExecutive == null ? 'Assign' : 'Change', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDocumentsUpload() {
    return Column(
      children: [
        _buildUploadBox('Passport / ID'),
        const SizedBox(height: 16),
        _buildUploadBox('Academic Transcripts'),
        const SizedBox(height: 16),
        _buildUploadBox('IELTS / English Proficiency'),
      ],
    );
  }

  Widget _buildUploadBox(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Iconex.light.cloudUpload, size: 32, color: AppColors.primary.withOpacity(0.8)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Tap to upload PDF or Image', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

*/

// --- NEW EXCEL-LIKE UI ---
class CreateLeadScreen extends StatefulWidget {
  final String? leadId;
  const CreateLeadScreen({super.key, this.leadId});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  final _controllers = <String, TextEditingController>{};

  final List<String> _fields = [
    'First Name',
    'Last Name',
    'Email',
    'Phone',
    'Address',
    'Agency Name',
    'Branch',
    'Counselor',
    'Course',
    'University',
    'Intake',
    'Total Amount',
    'Advance Amount',
    'Commission',
  ];

  @override
  void initState() {
    super.initState();
    for (var f in _fields) {
      _controllers[f] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveLead() {
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lead saved successfully!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Lead Record'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Iconex.light.check, color: AppColors.primary),
            onPressed: _saveLead,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(bottom: BorderSide(color: Colors.grey)),
          ),
          child: Column(
            children: _fields.map((field) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            field,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controllers[field],
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade100,
                    indent: 20,
                    endIndent: 20,
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
