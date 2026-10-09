import 'dart:io';
import 'package:get/get.dart';
import '../repositories/document_repository.dart';
import '../../../data/api/api_client.dart';
import '../../../data/api/api_constants.dart';
import '../../../../widgets/custom_snackbar.dart';
import '../document_upload_screen.dart';

class DocumentController extends GetxController {
  final DocumentRepository documentRepository;

  DocumentController({required this.documentRepository});

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString kycStatus =
      'not_submitted'.obs; // Public KYC status from backend.
  final RxString currentKycId = ''.obs; // Current KYC application ID
  final RxString rejectionReason = ''.obs;
  final RxString providerName = ''.obs;
  final RxString providerEmail = ''.obs;
  final RxString providerPhone = ''.obs;
  final RxMap<String, String> documentPrefillValues = <String, String>{}.obs;
  final RxMap<String, String> documentFileUrls = <String, String>{}.obs;

  // Track provider specific document status fields
  final RxBool aadharNumber = false.obs;
  final RxBool aadharCardFront = false.obs;
  final RxBool aadharCardBack = false.obs;
  final RxBool panNumber = false.obs;
  final RxBool panCardFront = false.obs;
  final RxBool panCardBack = false.obs;
  final RxBool bankName = false.obs;
  final RxBool accountNumber = false.obs;
  final RxBool ifscCode = false.obs;
  final RxBool bankProof = false.obs;

  // Track specific document rejection reasons
  final RxMap<String, String> documentRejectionReasons = <String, String>{}.obs;

  // Track status of each document type
  final RxMap<String, DocumentStatus> documentStatuses =
      <String, DocumentStatus>{
        'Aadhaar Card': DocumentStatus.pending,
        'Driving Licence': DocumentStatus.pending,
        'Vehicle RC': DocumentStatus.pending,
        'Vehicle Insurance': DocumentStatus.pending,
        'PAN Card': DocumentStatus.pending,
        'Bank Details': DocumentStatus.pending,
      }.obs;

  @override
  void onInit() {
    super.onInit();
    fetchKycStatus();
  }

  // Fetch KYC status from API
  Future<void> fetchKycStatus({bool isProviderKyc = false}) async {
    isLoading.value = true;
    try {
      final response = isProviderKyc
          ? await documentRepository.getProviderKycStatus()
          : await documentRepository.getKycStatus();

      if (!response.isOk) {
        final message = _responseMessage(response);
        if (message != null && message.isNotEmpty) {
          rejectionReason.value = message;
          CustomSnackbar.showError(message: message);
        } else {
          CustomSnackbar.showError(message: 'Failed to fetch KYC status');
        }
        return;
      }

      final data = _extractData(response.body);
      if (data == null) return;

      documentRejectionReasons.clear();

      final publicStatus = _publicStatusFromData(data);
      currentKycId.value =
          data['id']?.toString() ??
          data['_id']?.toString() ??
          data['kycId']?.toString() ??
          '';
      if (publicStatus != null && publicStatus.isNotEmpty) {
        kycStatus.value = publicStatus;
      }
      rejectionReason.value =
          data['rejectionReason']?.toString() ??
          data['reason']?.toString() ??
          data['message']?.toString() ??
          '';
      _applyProfile(data['profile']);
      _applyPrefillValues(data);

      if (isProviderKyc) {
        aadharNumber.value = _boolFlag(data, 'aadharNumber') || _boolFlag(data, 'aadhaarNumber');
        aadharCardFront.value = _boolFlag(data, 'aadharCardFront') || _boolFlag(data, 'aadhaarCardFront');
        aadharCardBack.value = _boolFlag(data, 'aadharCardBack') || _boolFlag(data, 'aadhaarCardBack');
        panNumber.value = _boolFlag(data, 'panNumber');
        panCardFront.value = _boolFlag(data, 'panCardFront');
        panCardBack.value = _boolFlag(data, 'panCardBack');
        bankName.value = _boolFlag(data, 'bankName');
        accountNumber.value = _boolFlag(data, 'accountNumber');
        ifscCode.value = _boolFlag(data, 'ifscCode');
        bankProof.value = _boolFlag(data, 'bankProof');
      } else {
        aadharNumber.value = false;
        aadharCardFront.value = false;
        aadharCardBack.value = false;
        panNumber.value = false;
        panCardFront.value = false;
        panCardBack.value = false;
        bankName.value = false;
        accountNumber.value = false;
        ifscCode.value = false;
        bankProof.value = false;
      }

      _applyKycStatus(data, isProviderKyc: isProviderKyc);
    } catch (e) {
      print('=== FETCH KYC STATUS ERROR ===');
      print(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // Upload individual KYC document
  Future<bool> uploadKycDocument({
    required String title,
    required Map<String, File> files,
    Map<String, String>? textFields,
    bool isProviderKyc = false,
  }) async {
    isLoading.value = true;
    try {
      final formData = FormData({});
      for (final entry in textFields?.entries ?? <MapEntry<String, String>>[]) {
        formData.fields.add(MapEntry(entry.key, entry.value));
      }

      String primaryFilename = '';
      int primaryFileSize = 0;
      bool primaryFileExists = false;
      for (final entry in files.entries) {
        final filename = _safeUploadFilename(entry.value);
        if (primaryFilename.isEmpty) {
          primaryFilename = filename;
          primaryFileExists = entry.value.existsSync();
          primaryFileSize = primaryFileExists ? entry.value.lengthSync() : 0;
        }
        formData.files.add(
          MapEntry(
            entry.key,
            MultipartFile(
              entry.value.path,
              filename: filename,
              contentType: _contentTypeFor(filename),
            ),
          ),
        );
      }

      print("=== KYC DOCUMENT UPLOAD ===");
      print("Document Type: $title");
      print("File Name: $primaryFilename");
      print("File Exists: $primaryFileExists");
      print("File Size: $primaryFileSize");
      print("Upload Started");

      bool isRejectedDoc = documentStatuses[title] == DocumentStatus.rejected;

      final response = isProviderKyc
          ? (isRejectedDoc
              ? await documentRepository.reuploadProviderKycDocument(formData)
              : await documentRepository.uploadProviderKycDocument(title, formData))
          : await documentRepository.uploadDocument(title, formData);

      final bool isSuccess = response.isOk &&
          (response.body == null ||
              (response.body is Map && response.body['success'] != false));

      print("=== KYC DOCUMENT UPLOAD RESULT ===");
      print("Document Type: $title");
      print("Status: ${response.statusCode}");
      print("Success: $isSuccess");
      print("Response: ${response.body}");

      if (!response.isOk) {
        final message = _responseMessage(response) ?? 'Failed to upload $title';
        CustomSnackbar.showError(message: message);
        return false;
      }

      if (isProviderKyc) {
        documentStatuses[title] = DocumentStatus.pending;
        kycStatus.value = 'pending';
      } else {
        documentStatuses[title] = DocumentStatus.underVerification;
      }
      await fetchKycStatus(isProviderKyc: isProviderKyc);
      CustomSnackbar.showSuccess(message: '$title uploaded successfully');

      return true;
    } catch (e) {
      print("=== KYC DOCUMENT UPLOAD RESULT ===");
      print("Document Type: $title");
      print("Status: Exception");
      print("Success: false");
      print("Response: ${e.toString()}");
      CustomSnackbar.showError(
        message: 'Error uploading document: ${e.toString()}',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submitForApproval({bool isProviderKyc = false}) async {
    if (!isProviderKyc) return false;
    isSubmitting.value = true;
    try {
      final response = await Get.find<ApiClient>().postData(
        ApiConstants.providerKycSubmitApproval,
        {},
      );
      if (response.isOk ||
          (response.body != null && response.body['success'] == true)) {
        await fetchKycStatus(isProviderKyc: true);
        CustomSnackbar.showSuccess(
          message: response.body['message'] ?? 'KYC submitted successfully',
        );
        return true;
      } else {
        CustomSnackbar.showError(
          message: response.body['message'] ?? 'Failed to submit KYC',
        );
        return false;
      }
    } catch (e) {
      print("=== SUBMIT KYC ERROR ===");
      print(e.toString());
      CustomSnackbar.showError(message: 'Something went wrong');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  String? _responseMessage(Response response) {
    final body = response.body;
    if (body is Map) {
      return body['message']?.toString() ?? body['error']?.toString();
    }
    return response.statusText;
  }

  String _safeUploadFilename(File file) {
    final originalName = file.path.split(Platform.pathSeparator).last;
    final lowerName = originalName.toLowerCase();
    if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.pdf')) {
      return originalName;
    }
    return '$originalName.jpg';
  }

  String _contentTypeFor(String filename) {
    final lowerName = filename.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Map<String, dynamic>? _extractData(dynamic body) {
    if (body is! Map) return null;
    final raw = body['data'] ?? body['kyc'] ?? body['providerKyc'] ?? body;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? _publicStatusFromData(Map<String, dynamic> data) {
    final status =
        data['status']?.toString() ??
        data['publicStatus']?.toString() ??
        data['kycStatus']?.toString();
    if (status != null && status.trim().isNotEmpty) return status.trim();
    if (_boolFlag(data, 'isApproved')) return 'approved';
    return null;
  }

  void _applyKycStatus(
    Map<String, dynamic> data, {
    required bool isProviderKyc,
  }) {
    if (isProviderKyc) {
      _applyProviderKycStatus(data);
      return;
    }

    final kyc = data['kyc'];
    final docs =
        data['docs'] ??
        data['kycDocuments'] ??
        (kyc is Map ? kyc['docs'] : null) ??
        (kyc is Map ? kyc['kycDocuments'] : null) ??
        data['documents'] ??
        data['files'] ??
        data['uploads'];
    final hasSubmittedDocs = _hasSubmittedDocuments(data, kyc, docs);
    final globalStatus = hasSubmittedDocs
        ? _toDocumentStatus(kycStatus.value)
        : DocumentStatus.pending;

    if (isProviderKyc) {
      if (!hasSubmittedDocs) {
        for (final title in ['Aadhaar Card', 'PAN Card', 'Bank Details']) {
          documentStatuses[title] = DocumentStatus.pending;
        }
        documentPrefillValues.clear();
        documentFileUrls.clear();
        return;
      }
    }

    _applyDocumentStatusFromData(
      title: 'Aadhaar Card',
      data: data,
      docs: docs,
      keys: const ['aadhaar', 'aadhaarCard', 'aadhaarFront', 'aadhaarBack'],
      fallback: globalStatus,
    );
    _applyDocumentStatusFromData(
      title: 'PAN Card',
      data: data,
      docs: docs,
      keys: const ['pan', 'panCard', 'panFront'],
      fallback: globalStatus,
    );
    _applyDocumentStatusFromData(
      title: 'Bank Details',
      data: data,
      docs: docs,
      keys: const ['bank', 'bankDetails', 'bankProof', 'bankFront'],
      fallback: globalStatus,
    );
  }

  void _applyProviderKycStatus(Map<String, dynamic> data) {
    var status = kycStatus.value.toLowerCase().trim();
    if (_boolFlag(data, 'isApproved')) {
      status = 'approved';
      kycStatus.value = 'approved';
    }

    final kyc = data['kyc'];
    final docs =
        data['documents'] ??
        data['docs'] ??
        (kyc is Map ? kyc['documents'] : null) ??
        (kyc is Map ? kyc['docs'] : null);
    final sectionFallback = _toDocumentStatus(status);


    final aadhaarApiStatus = _providerSectionStatusFromDocs(docs, const [
      'aadhaar',
      'aadhar',
    ], sectionFallback);
    final panApiStatus = _providerSectionStatusFromDocs(docs, const [
      'pan',
    ], sectionFallback);
    final bankApiStatus = _providerSectionStatusFromDocs(docs, const [
      'bank',
      'passbook',
    ], sectionFallback);

    // Parse accepted & rejected lists from backend response
    final List<dynamic> rejectedDocsList = data['rejectedDocuments'] ?? [];
    final List<dynamic> acceptedDocsList = data['acceptedDocuments'] ?? [];

    bool isDocTypeMatch(String docType, String title) {
      final normalized = docType.toLowerCase().trim();
      if (title == 'Aadhaar Card') {
        return normalized.contains('aadhar') || normalized.contains('aadhaar');
      }
      if (title == 'PAN Card') {
        return normalized.contains('pan');
      }
      if (title == 'Bank Details') {
        return normalized.contains('bank') || normalized.contains('passbook');
      }
      return false;
    }

    String? getDocRejectionReason(String title) {
      for (final item in rejectedDocsList) {
        if (item is Map) {
          final type = item['type']?.toString() ?? '';
          if (isDocTypeMatch(type, title)) {
            return item['reason']?.toString() ?? item['message']?.toString() ?? 'Rejected';
          }
        }
      }
      return null;
    }

    bool isDocRejected(String title) {
      return getDocRejectionReason(title) != null;
    }

    bool isDocAccepted(String title) {
      for (final item in acceptedDocsList) {
        if (item is Map) {
          final type = item['type']?.toString() ?? '';
          if (isDocTypeMatch(type, title)) {
            return true;
          }
        }
      }
      return false;
    }

    DocumentStatus getProviderDocStatus(String title, bool isUploaded, {DocumentStatus? apiStatus}) {
      if (isDocRejected(title)) {
        return DocumentStatus.rejected;
      }
      if (isDocAccepted(title) || apiStatus == DocumentStatus.approved || status == 'approved') {
        return DocumentStatus.approved;
      }
      if (apiStatus == DocumentStatus.rejected) {
        return DocumentStatus.rejected;
      }
      if (apiStatus == DocumentStatus.underVerification) {
        return DocumentStatus.underVerification;
      }
      if (isUploaded) {
        return (status == 'under_verification' || status == 'submitted')
            ? DocumentStatus.underVerification
            : DocumentStatus.pending;
      }
      return DocumentStatus.pending;
    }

    final isAadharUploaded = aadharNumber.value && aadharCardFront.value && aadharCardBack.value;
    final isPanUploaded = panNumber.value && panCardFront.value && panCardBack.value;
    final isBankUploaded = bankName.value && accountNumber.value && ifscCode.value && bankProof.value;

    documentStatuses['Aadhaar Card'] = getProviderDocStatus('Aadhaar Card', isAadharUploaded, apiStatus: aadhaarApiStatus);
    documentStatuses['PAN Card'] = getProviderDocStatus('PAN Card', isPanUploaded, apiStatus: panApiStatus);
    documentStatuses['Bank Details'] = getProviderDocStatus('Bank Details', isBankUploaded, apiStatus: bankApiStatus);

    for (final title in ['Aadhaar Card', 'PAN Card', 'Bank Details']) {
      final reason = getDocRejectionReason(title);
      if (reason != null) {
        documentRejectionReasons[title] = reason;
      }
    }
  }

  DocumentStatus? _providerSectionStatusFromDocs(
    dynamic docs,
    List<String> sectionKeys,
    DocumentStatus fallback,
  ) {
    if (docs is! List) return null;

    final sectionStatuses = <DocumentStatus>[];
    for (final item in docs) {
      if (item is! Map) continue;
      final key = [
        item['key'],
        item['sectionKey'],
        item['label'],
        item['type'],
        item['name'],
      ].whereType<Object>().join(' ').toLowerCase();
      if (!sectionKeys.any(key.contains)) continue;
      sectionStatuses.add(_statusFromValue(item, fallback));
    }

    if (sectionStatuses.isEmpty) return null;
    if (sectionStatuses.any((status) => status == DocumentStatus.rejected)) {
      return DocumentStatus.rejected;
    }
    if (sectionStatuses.every((status) => status == DocumentStatus.approved)) {
      return DocumentStatus.approved;
    }
    if (sectionStatuses.any(
      (status) => status == DocumentStatus.underVerification,
    )) {
      return DocumentStatus.underVerification;
    }
    return DocumentStatus.pending;
  }

  bool _boolFlag(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  bool _hasSubmittedDocuments(
    Map<String, dynamic> data,
    dynamic kyc,
    dynamic docs,
  ) {
    final approvalSummary = data['approvalSummary'];
    if (approvalSummary is Map) {
      final submittedCount = int.tryParse(
        approvalSummary['submittedCount']?.toString() ?? '',
      );
      if (submittedCount != null) return submittedCount > 0;
    }
    if (docs is List) return docs.isNotEmpty;
    if (docs is Map) return docs.isNotEmpty;
    if (kyc is Map) return kyc.isNotEmpty;
    return false;
  }

  void _applyProfile(dynamic profile) {
    if (profile is! Map) return;
    final user = profile['user'];
    providerName.value =
        profile['name']?.toString() ??
        (user is Map ? user['name']?.toString() : null) ??
        providerName.value;
    providerEmail.value =
        profile['email']?.toString() ??
        (user is Map ? user['email']?.toString() : null) ??
        providerEmail.value;
    providerPhone.value =
        profile['phone']?.toString() ??
        (user is Map ? user['phone']?.toString() : null) ??
        providerPhone.value;
  }

  void _applyPrefillValues(Map<String, dynamic> data) {
    final kyc = (data['kyc'] is Map) ? data['kyc'] : data;

    _setPrefill('Aadhaar Card', kyc['aadhaarNumber']);
    _setPrefill(
      'PAN Card',
      kyc['panNumber'] ?? kyc['panCardNumber'] ?? kyc['pan'],
    );

    final bank = kyc['bankDetails'] ?? kyc['bank'] ?? kyc;
    if (bank is Map) {
      _setPrefill('Bank Name', bank['bankName'] ?? bank['name']);
      _setPrefill(
        'Bank Account Number',
        bank['bankAccountNumber'] ??
            bank['accountNumber'] ??
            bank['account_number'],
      );
      _setPrefill(
        'Bank IFSC',
        bank['bankIfscCode'] ?? bank['ifscCode'] ?? bank['ifsc'],
      );
      _setPrefill(
        'Bank Account Holder',
        bank['bankAccountHolderName'] ??
            bank['accountHolderName'] ??
            bank['account_holder_name'],
      );
    }

    final personalInfo = kyc['personalInfo'] ?? kyc;
    if (personalInfo is Map) {
      _setPrefill('fullName', personalInfo['fullName'] ?? personalInfo['name']);
      _setPrefill('dob', personalInfo['dob']);
      _setPrefill(
        'mobileNumber',
        personalInfo['mobileNumber'] ?? personalInfo['phone'],
      );
    }

    _setDocumentUrl(
      'Aadhaar Card Front',
      kyc['aadhaarFront'] ??
          kyc['aadharCardFrontUrl'] ??
          (kyc['aadhaar'] is Map ? kyc['aadhaar']['frontUrl'] : null),
    );
    _setDocumentUrl(
      'Aadhaar Card Back',
      kyc['aadhaarBack'] ??
          kyc['aadharCardBackUrl'] ??
          (kyc['aadhaar'] is Map ? kyc['aadhaar']['backUrl'] : null),
    );
    _setDocumentUrl(
      'PAN Card Front',
      kyc['panFront'] ??
          kyc['panCard'] ??
          kyc['panCardFrontUrl'] ??
          (kyc['pan'] is Map ? kyc['pan']['frontUrl'] : null),
    );
    _setDocumentUrl(
      'PAN Card Back',
      kyc['panCardBackUrl'] ??
          (kyc['pan'] is Map ? kyc['pan']['backUrl'] : null),
    );
    _setDocumentUrl(
      'Bank Details Front',
      kyc['bankProof'] ??
          kyc['bankFront'] ??
          kyc['bankProofUrl'] ??
          (kyc['bank'] is Map ? kyc['bank']['frontUrl'] : null),
    );
    _applyProviderDocumentUrls(
      data['documents'] ??
          data['docs'] ??
          (kyc is Map ? kyc['documents'] : null) ??
          (kyc is Map ? kyc['docs'] : null),
    );
  }

  void _applyProviderDocumentUrls(dynamic docs) {
    if (docs is! List) return;

    for (final item in docs) {
      if (item is! Map) continue;
      final key = [
        item['key'],
        item['sectionKey'],
        item['label'],
        item['type'],
        item['name'],
      ].whereType<Object>().join(' ').toLowerCase();
      final side = item['side']?.toString().toLowerCase() ?? '';

      if (key.contains('aadhaar') || key.contains('aadhar')) {
        if (side == 'back' || key.contains('back')) {
          _setDocumentUrl('Aadhaar Card Back', item);
        } else {
          _setDocumentUrl('Aadhaar Card Front', item);
        }
      } else if (key.contains('pan')) {
        if (side == 'back' || key.contains('back')) {
          _setDocumentUrl('PAN Card Back', item);
        } else {
          _setDocumentUrl('PAN Card Front', item);
        }
      } else if (key.contains('bank') || key.contains('passbook')) {
        _setDocumentUrl('Bank Details Front', item);
      }
    }
  }

  void _setPrefill(String key, dynamic value) {
    if (value is bool) return;
    final text = value?.toString() ?? '';
    if (text.trim().isNotEmpty && text != 'null') {
      documentPrefillValues[key] = text;
    }
  }

  void _setDocumentUrl(String title, dynamic value) {
    if (value is bool) return;
    final fullUrl = _fullFileUrl(_fileUrlFromValue(value));
    if (fullUrl.isNotEmpty) {
      documentFileUrls[title] = fullUrl;
    }
  }

  String _fileUrlFromValue(dynamic value) {
    if (value is Map) {
      return value['fileUrl']?.toString() ??
          value['url']?.toString() ??
          value['documentUrl']?.toString() ??
          value['imageUrl']?.toString() ??
          value['path']?.toString() ??
          '';
    }
    if (value is bool) return '';
    return value?.toString() ?? '';
  }

  String _fullFileUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty || url == 'null') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/data/') || url.startsWith('file:')) return '';
    if (url.startsWith('/api/')) {
      return '${ApiConstants.fileBaseUrl}${url.substring(4)}';
    }
    if (url.startsWith('/')) return '${ApiConstants.fileBaseUrl}$url';
    return '${ApiConstants.fileBaseUrl}/$url';
  }

  void _applyDocumentStatusFromData({
    required String title,
    required Map<String, dynamic> data,
    required dynamic docs,
    required List<String> keys,
    required DocumentStatus fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        documentStatuses[title] = _statusFromValue(value, fallback);
        _setDocumentUrl(title, value);
        final reason = _rejectionReasonFromValue(value);
        if (reason != null && reason.isNotEmpty) {
          documentRejectionReasons[title] = reason;
        }
        return;
      }
    }

    if (docs is Map) {
      for (final key in keys) {
        final value = docs[key];
        if (value != null) {
          documentStatuses[title] = _statusFromValue(value, fallback);
          _setDocumentUrl(title, value);
          final reason = _rejectionReasonFromValue(value);
          if (reason != null && reason.isNotEmpty) {
            documentRejectionReasons[title] = reason;
          }
          return;
        }
      }
    }

    if (docs is List) {
      for (final item in docs) {
        if (item is! Map) continue;
        final type =
            item['type']?.toString().toLowerCase() ??
            item['name']?.toString().toLowerCase() ??
            item['field']?.toString().toLowerCase() ??
            item['fieldName']?.toString().toLowerCase() ??
            item['sourceType']?.toString().toLowerCase() ??
            item['key']?.toString().toLowerCase() ??
            item['sectionKey']?.toString().toLowerCase() ??
            '';
        if (keys.any((key) => type.contains(key.toLowerCase()))) {
          documentStatuses[title] = _statusFromValue(item, fallback);
          _setDocumentUrl(title, item);
          final reason = _rejectionReasonFromValue(item);
          if (reason != null && reason.isNotEmpty) {
            documentRejectionReasons[title] = reason;
          }
          return;
        }
      }
    }

    // If not found in API response, it should be pending (needs upload)
    documentStatuses[title] = DocumentStatus.pending;
  }

  String? _rejectionReasonFromValue(dynamic value) {
    if (value is Map) {
      return value['rejectionReason']?.toString() ??
          value['reason']?.toString() ??
          value['message']?.toString();
    }
    return null;
  }

  DocumentStatus _statusFromValue(dynamic value, DocumentStatus fallback) {
    if (value is Map) {
      return _toDocumentStatus(
        value['status']?.toString() ??
            value['kycStatus']?.toString() ??
            value['newStatus']?.toString() ??
            fallback.name,
      );
    }
    if (value is String) {
      return value.trim().isEmpty ? fallback : _toDocumentStatus(value);
    }
    return fallback;
  }

  DocumentStatus _toDocumentStatus(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized.contains('approve') || normalized == 'verified') {
      return DocumentStatus.approved;
    }
    if (normalized.contains('reject')) return DocumentStatus.rejected;
    if (normalized == 'pending') return DocumentStatus.pending;
    if (normalized.contains('under') ||
        normalized.contains('submitted') ||
        normalized.contains('review') ||
        normalized.contains('verify')) {
      return DocumentStatus.underVerification;
    }
    return DocumentStatus.pending;
  }

  Future<Response> fetchDriverKycDetails() async {
    return await documentRepository.getKycDetails();
  }

  Future<bool> submitDriverKyc(dynamic data) async {
    isSubmitting.value = true;
    try {
      final response = await documentRepository.submitKyc(data);
      if (response.isOk) {
        await fetchKycStatus();
        CustomSnackbar.showSuccess(message: 'KYC submitted successfully');
        return true;
      }
      CustomSnackbar.showError(
        message: _responseMessage(response) ?? 'Failed to submit KYC',
      );
      return false;
    } catch (e) {
      CustomSnackbar.showError(message: 'Error submitting KYC: $e');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}

