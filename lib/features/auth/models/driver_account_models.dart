// Driver Account and Vehicle Models
// Fully null-safe parsing and formatting for backend API responses

String? _asNullableString(dynamic val) {
  if (val == null) return null;
  final str = val.toString().trim();
  if (str.isEmpty || str == 'null') return null;
  return str;
}

String _asString(dynamic val, {String fallback = 'Not provided'}) {
  final str = _asNullableString(val);
  return str ?? fallback;
}

int? _asNullableInt(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString());
}

bool _asBool(dynamic val, {bool fallback = false}) {
  if (val == null) return fallback;
  if (val is bool) return val;
  if (val is num) return val == 1;
  final s = val.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

// -------------------------------------------------------------
// Driver Account Info Models
// -------------------------------------------------------------

class AddressInfo {
  final String addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  AddressInfo({
    required this.addressLine1,
    this.addressLine2,
    this.landmark,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  factory AddressInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AddressInfo(
        addressLine1: 'Not provided',
        city: 'Not provided',
        state: 'Not provided',
        postalCode: 'Not provided',
        country: 'Not provided',
      );
    }
    return AddressInfo(
      addressLine1: _asString(json['addressLine1']),
      addressLine2: _asNullableString(json['addressLine2']),
      landmark: _asNullableString(json['landmark']),
      city: _asString(json['city']),
      state: _asString(json['state']),
      postalCode: _asString(json['postalCode']),
      country: _asString(json['country']),
    );
  }
}

class PersonalInfo {
  final String fullName;
  final String email;
  final String phone;
  final bool phoneVerified;
  final String accountStatus;
  final String gender;
  final String? dateOfBirth;
  final String? alternatePhone;
  final String? profileImageUrl;
  final AddressInfo address;

  PersonalInfo({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.phoneVerified,
    required this.accountStatus,
    required this.gender,
    this.dateOfBirth,
    this.alternatePhone,
    this.profileImageUrl,
    required this.address,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PersonalInfo(
        fullName: 'Driver',
        email: 'Not provided',
        phone: 'Not provided',
        phoneVerified: false,
        accountStatus: 'UNKNOWN',
        gender: 'Not provided',
        address: AddressInfo.fromJson(null),
      );
    }
    return PersonalInfo(
      fullName: _asString(json['fullName'], fallback: 'Driver'),
      email: _asString(json['email']),
      phone: _asString(json['phone']),
      phoneVerified: _asBool(json['phoneVerified']),
      accountStatus: _asString(json['accountStatus'], fallback: 'ACTIVE'),
      gender: _asString(json['gender']),
      dateOfBirth: _asNullableString(json['dateOfBirth']),
      alternatePhone: _asNullableString(json['alternatePhone']),
      profileImageUrl: _asNullableString(json['profileImageUrl']),
      address: AddressInfo.fromJson(json['address'] is Map<String, dynamic>
          ? json['address'] as Map<String, dynamic>
          : (json['address'] is Map ? Map<String, dynamic>.from(json['address']) : null)),
    );
  }
}

class KycSubmission {
  final String status;
  final String? submittedAt;
  final String? reviewedAt;

  KycSubmission({
    required this.status,
    this.submittedAt,
    this.reviewedAt,
  });

  factory KycSubmission.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KycSubmission(status: 'NOT_SUBMITTED');
    }
    return KycSubmission(
      status: _asString(json['status'], fallback: 'PENDING'),
      submittedAt: _asNullableString(json['submittedAt']),
      reviewedAt: _asNullableString(json['reviewedAt']),
    );
  }
}

class KycDocumentItem {
  final String documentNo;
  final String status;
  final String? expiresAt;
  final String? imageUrl;
  final String? frontImageUrl;
  final String? backImageUrl;

  KycDocumentItem({
    required this.documentNo,
    required this.status,
    this.expiresAt,
    this.imageUrl,
    this.frontImageUrl,
    this.backImageUrl,
  });

  factory KycDocumentItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KycDocumentItem(documentNo: 'Not provided', status: 'VERIFIED');
    }
    final docNum = _asNullableString(
      json['documentNo'] ??
      json['documentNumber'] ??
      json['docNo'] ??
      json['number'] ??
      json['aadhaarNumber'] ??
      json['panNumber'] ??
      json['aadhaar_number'] ??
      json['pan_number'] ??
      json['idNumber']
    ) ?? 'Not provided';

    final frontImg = _asNullableString(
      json['frontImageUrl'] ?? json['frontUrl'] ?? json['aadhaarFront'] ?? json['aadhaarFrontUrl'] ?? json['imageUrl'] ?? json['url'] ?? json['documentUrl']
    );

    return KycDocumentItem(
      documentNo: docNum,
      status: _asString(json['status'], fallback: 'VERIFIED'),
      expiresAt: _asNullableString(json['expiresAt']),
      imageUrl: frontImg ?? _asNullableString(json['imageUrl'] ?? json['url']),
      frontImageUrl: frontImg,
      backImageUrl: _asNullableString(
        json['backUrl'] ?? json['backImageUrl'] ?? json['aadhaarBack'] ?? json['aadhaarBackUrl']
      ),
    );
  }
}

class KycInfo {
  final String status;
  final String onboardingStatus;
  final String? verifiedAt;
  final KycSubmission submission;
  final KycDocumentItem aadhaar;
  final KycDocumentItem pan;

  KycInfo({
    required this.status,
    required this.onboardingStatus,
    this.verifiedAt,
    required this.submission,
    required this.aadhaar,
    required this.pan,
  });

  factory KycInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KycInfo(
        status: 'VERIFIED',
        onboardingStatus: 'VERIFIED',
        submission: KycSubmission.fromJson(null),
        aadhaar: KycDocumentItem.fromJson(null),
        pan: KycDocumentItem.fromJson(null),
      );
    }

    Map<String, dynamic>? aadhaarMap;
    if (json['aadhaar'] is Map) {
      aadhaarMap = Map<String, dynamic>.from(json['aadhaar']);
    } else if (json['aadhar'] is Map) {
      aadhaarMap = Map<String, dynamic>.from(json['aadhar']);
    } else if (json['aadhaarNumber'] != null || json['aadhaar_number'] != null || json['aadhaarFront'] != null || json['aadhaarUrl'] != null) {
      aadhaarMap = {
        'documentNo': json['aadhaarNumber'] ?? json['aadhaar_number'],
        'status': json['aadhaarStatus'] ?? json['aadhaar_status'] ?? 'VERIFIED',
        'imageUrl': json['aadhaarFront'] ?? json['aadhaarUrl'] ?? json['aadhaarFrontUrl'] ?? json['aadhaar_front_url'],
        'backImageUrl': json['aadhaarBack'] ?? json['aadhaarBackUrl'] ?? json['aadhaar_back_url'],
      };
    }

    Map<String, dynamic>? panMap;
    if (json['pan'] is Map) {
      panMap = Map<String, dynamic>.from(json['pan']);
    } else if (json['panNumber'] != null || json['pan_number'] != null || json['panFront'] != null || json['panUrl'] != null) {
      panMap = {
        'documentNo': json['panNumber'] ?? json['pan_number'],
        'status': json['panStatus'] ?? json['pan_status'] ?? 'VERIFIED',
        'imageUrl': json['panFront'] ?? json['panUrl'] ?? json['panCard'] ?? json['pan_url'],
      };
    }

    return KycInfo(
      status: _asString(json['status'], fallback: 'VERIFIED'),
      onboardingStatus: _asString(json['onboardingStatus'], fallback: 'VERIFIED'),
      verifiedAt: _asNullableString(json['verifiedAt']),
      submission: KycSubmission.fromJson(json['submission'] is Map ? Map<String, dynamic>.from(json['submission']) : null),
      aadhaar: KycDocumentItem.fromJson(aadhaarMap),
      pan: KycDocumentItem.fromJson(panMap),
    );
  }
}

class LicenseSubDocument {
  final String status;
  final String? expiresAt;
  final String? verifiedAt;
  final String? imageUrl;

  LicenseSubDocument({
    required this.status,
    this.expiresAt,
    this.verifiedAt,
    this.imageUrl,
  });

  factory LicenseSubDocument.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LicenseSubDocument(status: 'VERIFIED');
    }
    return LicenseSubDocument(
      status: _asString(json['status'], fallback: 'VERIFIED'),
      expiresAt: _asNullableString(json['expiresAt']),
      verifiedAt: _asNullableString(json['verifiedAt']),
      imageUrl: _asNullableString(
        json['imageUrl'] ?? json['url'] ?? json['frontUrl'] ?? json['backUrl'] ?? json['documentUrl']
      ),
    );
  }
}

class DrivingLicenseInfo {
  final String licenseNumber;
  final String? issueDate;
  final String? expiryDate;
  final int? experienceYears;
  final String status;
  final LicenseSubDocument frontDocument;
  final LicenseSubDocument backDocument;

  DrivingLicenseInfo({
    required this.licenseNumber,
    this.issueDate,
    this.expiryDate,
    this.experienceYears,
    required this.status,
    required this.frontDocument,
    required this.backDocument,
  });

  factory DrivingLicenseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DrivingLicenseInfo(
        licenseNumber: 'Not provided',
        status: 'VERIFIED',
        frontDocument: LicenseSubDocument.fromJson(null),
        backDocument: LicenseSubDocument.fromJson(null),
      );
    }

    Map<String, dynamic>? frontMap;
    if (json['frontDocument'] is Map) {
      frontMap = Map<String, dynamic>.from(json['frontDocument']);
    } else if (json['dlFront'] != null || json['frontImageUrl'] != null || json['dlFrontUrl'] != null) {
      frontMap = {
        'status': json['status'] ?? 'VERIFIED',
        'imageUrl': json['dlFront'] ?? json['frontImageUrl'] ?? json['dlFrontUrl'],
      };
    }

    Map<String, dynamic>? backMap;
    if (json['backDocument'] is Map) {
      backMap = Map<String, dynamic>.from(json['backDocument']);
    } else if (json['dlBack'] != null || json['backImageUrl'] != null || json['dlBackUrl'] != null) {
      backMap = {
        'status': json['status'] ?? 'VERIFIED',
        'imageUrl': json['dlBack'] ?? json['backImageUrl'] ?? json['dlBackUrl'],
      };
    }

    return DrivingLicenseInfo(
      licenseNumber: _asString(
        json['licenseNumber'] ?? json['number'] ?? json['licenseNo']
      ),
      issueDate: _asNullableString(json['issueDate']),
      expiryDate: _asNullableString(json['expiryDate']),
      experienceYears: _asNullableInt(json['experienceYears']),
      status: _asString(json['status'], fallback: 'VERIFIED'),
      frontDocument: LicenseSubDocument.fromJson(frontMap),
      backDocument: LicenseSubDocument.fromJson(backMap),
    );
  }
}

class BankAccountInfo {
  final String accountName;
  final String accountNumber;
  final String bankName;
  final String ifscCode;
  final bool isDefault;
  final String status;

  BankAccountInfo({
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
    required this.ifscCode,
    required this.isDefault,
    required this.status,
  });

  factory BankAccountInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return BankAccountInfo(
        accountName: 'Not provided',
        accountNumber: 'Not provided',
        bankName: 'Not provided',
        ifscCode: 'Not provided',
        isDefault: false,
        status: 'PENDING',
      );
    }
    return BankAccountInfo(
      accountName: _asString(json['accountName']),
      accountNumber: _asString(json['accountNumber']),
      bankName: _asString(json['bankName']),
      ifscCode: _asString(json['ifscCode']),
      isDefault: _asBool(json['isDefault']),
      status: _asString(json['status'], fallback: 'PENDING'),
    );
  }
}

class DriverAccountInfo {
  final PersonalInfo personalInfo;
  final KycInfo kyc;
  final DrivingLicenseInfo drivingLicense;
  final BankAccountInfo bankAccount;

  DriverAccountInfo({
    required this.personalInfo,
    required this.kyc,
    required this.drivingLicense,
    required this.bankAccount,
  });

  factory DriverAccountInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
    return DriverAccountInfo(
      personalInfo: PersonalInfo.fromJson(data['personalInfo'] is Map ? Map<String, dynamic>.from(data['personalInfo']) : null),
      kyc: KycInfo.fromJson(data['kyc'] is Map ? Map<String, dynamic>.from(data['kyc']) : null),
      drivingLicense: DrivingLicenseInfo.fromJson(data['drivingLicense'] is Map ? Map<String, dynamic>.from(data['drivingLicense']) : null),
      bankAccount: BankAccountInfo.fromJson(data['bankAccount'] is Map ? Map<String, dynamic>.from(data['bankAccount']) : null),
    );
  }
}

// -------------------------------------------------------------
// Driver Vehicle Info Models
// -------------------------------------------------------------

class VehicleCategoryInfo {
  final String name;

  VehicleCategoryInfo({required this.name});

  factory VehicleCategoryInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VehicleCategoryInfo(name: '');
    return VehicleCategoryInfo(name: _asString(json['name'], fallback: ''));
  }
}

class VehicleAssignmentInfo {
  final String? assignedAt;
  final bool isActive;

  VehicleAssignmentInfo({this.assignedAt, required this.isActive});

  factory VehicleAssignmentInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VehicleAssignmentInfo(isActive: false);
    return VehicleAssignmentInfo(
      assignedAt: _asNullableString(json['assignedAt']),
      isActive: _asBool(json['isActive']),
    );
  }
}

class VehicleDetailsInfo {
  final String vehicleId;
  final String registrationNumber;
  final String make;
  final String model;
  final String color;
  final int? year;
  final int? seatingCapacity;
  final String fuelType;
  final String currentAddress;
  final VehicleCategoryInfo category;
  final String status;
  final String verificationStatus;
  final bool isAvailable;
  final VehicleAssignmentInfo assignment;

  VehicleDetailsInfo({
    required this.vehicleId,
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.color,
    this.year,
    this.seatingCapacity,
    required this.fuelType,
    required this.currentAddress,
    required this.category,
    required this.status,
    required this.verificationStatus,
    required this.isAvailable,
    required this.assignment,
  });

  factory VehicleDetailsInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return null as dynamic;
    return VehicleDetailsInfo(
      vehicleId: _asString(json['vehicleId']),
      registrationNumber: _asString(json['registrationNumber']),
      make: _asString(json['make']),
      model: _asString(json['model']),
      color: _asString(json['color']),
      year: _asNullableInt(json['year']),
      seatingCapacity: _asNullableInt(json['seatingCapacity']),
      fuelType: _asString(json['fuelType']),
      currentAddress: _asString(json['currentAddress']),
      category: VehicleCategoryInfo.fromJson(json['category'] is Map ? Map<String, dynamic>.from(json['category']) : null),
      status: _asString(json['status'], fallback: 'ACTIVE'),
      verificationStatus: _asString(json['verificationStatus'], fallback: 'APPROVED'),
      isAvailable: _asBool(json['isAvailable']),
      assignment: VehicleAssignmentInfo.fromJson(json['assignment'] is Map ? Map<String, dynamic>.from(json['assignment']) : null),
    );
  }
}

class VehicleDocumentItem {
  final String documentType; // "RC", "INSURANCE", etc.
  final String? documentNumber;
  final String? provider;
  final String? policyNumber;
  final String? validFrom;
  final String? expiry;
  final String status;
  final String? imageUrl;

  VehicleDocumentItem({
    required this.documentType,
    this.documentNumber,
    this.provider,
    this.policyNumber,
    this.validFrom,
    this.expiry,
    required this.status,
    this.imageUrl,
  });

  factory VehicleDocumentItem.fromJson(String type, Map<String, dynamic> json) {
    return VehicleDocumentItem(
      documentType: type,
      documentNumber: _asNullableString(json['documentNumber'] ?? json['rcNumber'] ?? json['number']),
      provider: _asNullableString(json['provider']),
      policyNumber: _asNullableString(json['policyNumber']),
      validFrom: _asNullableString(json['validFrom']),
      expiry: _asNullableString(json['expiry'] ?? json['expiryDate'] ?? json['expiresAt']),
      status: _asString(json['status'], fallback: 'VERIFIED'),
      imageUrl: _asNullableString(json['imageUrl'] ?? json['url']),
    );
  }
}

class DriverVehicleInfo {
  final VehicleDetailsInfo? vehicleDetails;
  final List<VehicleDocumentItem> vehicleDocuments;

  DriverVehicleInfo({
    this.vehicleDetails,
    required this.vehicleDocuments,
  });

  factory DriverVehicleInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
    
    VehicleDetailsInfo? vDetails;
    if (data['vehicleDetails'] is Map) {
      vDetails = VehicleDetailsInfo.fromJson(Map<String, dynamic>.from(data['vehicleDetails']));
    }

    final docsList = <VehicleDocumentItem>[];
    if (data['vehicleDocuments'] is Map) {
      final docsMap = Map<String, dynamic>.from(data['vehicleDocuments']);
      docsMap.forEach((key, val) {
        if (val != null && val is Map) {
          final docTypeLabel = key.toUpperCase();
          docsList.add(VehicleDocumentItem.fromJson(docTypeLabel, Map<String, dynamic>.from(val)));
        }
      });
    }

    return DriverVehicleInfo(
      vehicleDetails: vDetails,
      vehicleDocuments: docsList,
    );
  }
}
