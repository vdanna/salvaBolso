import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';

import '../../../core/network/api_client.dart';
import 'import_models.dart';

class ImportApi {
  ImportApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AccountCsvPreview> previewAccountCsv({
    required int accountId,
    required XFile file,
  }) async {
    final response = await _apiClient.dio.post(
      '/imports/account-csv/preview',
      data: await _buildFormData(
        accountId: accountId,
        file: file,
      ),
    );

    return AccountCsvPreview.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CsvImportResult> importAccountCsv({
    required int accountId,
    required XFile file,
  }) async {
    final response = await _apiClient.dio.post(
      '/imports/account-csv',
      data: await _buildFormData(
        accountId: accountId,
        file: file,
      ),
    );

    return CsvImportResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CreditCardCsvPreview> previewCreditCardCsv({
    required int accountId,
    required XFile file,
  }) async {
    final response = await _apiClient.dio.post(
      '/imports/credit-card-csv/preview',
      data: await _buildFormData(
        accountId: accountId,
        file: file,
      ),
    );

    return CreditCardCsvPreview.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CsvImportResult> importCreditCardCsv({
    required int accountId,
    required XFile file,
  }) async {
    final response = await _apiClient.dio.post(
      '/imports/credit-card-csv',
      data: await _buildFormData(
        accountId: accountId,
        file: file,
      ),
    );

    return CsvImportResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FormData> _buildFormData({
    required int accountId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();

    final multipartFile = MultipartFile.fromBytes(
      bytes,
      filename: file.name,
    );

    return FormData.fromMap({
      'account_id': accountId.toString(),
      'file': multipartFile,
    });
  }
}