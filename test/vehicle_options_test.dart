import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:driver_flutter/data/api/api_client.dart';
import 'package:driver_flutter/features/auth/controllers/auth_controller.dart';
import 'package:driver_flutter/features/auth/repositories/auth_repository.dart';

class OptionsRepository extends AuthRepository {
  OptionsRepository(this.response) : super(apiClient: ApiClient());
  Response response;

  @override
  Future<Response> getVehicleOptions() async => response;
}

void main() {
  test(
    'options preserve backend names, IDs, relationships and numeric years',
    () async {
      final controller = AuthController(
        authRepository: OptionsRepository(
          const Response(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'categories': [
                  {'id': 'category-uuid', 'name': 'Dynamic Category'},
                ],
                'brands': [
                  {'id': 'brand-uuid', 'name': 'Hyundai'},
                ],
                'models': [
                  {
                    'id': 'model-uuid',
                    'name': 'Verna',
                    'brandId': 'brand-uuid',
                    'categoryId': 'category-uuid',
                  },
                ],
                'manufacturerYears': [
                  {'id': 'year-uuid', 'year': 2026},
                ],
                'years': [2026],
              },
            },
          ),
        ),
      );
      final options = await controller.fetchVehicleOptions();
      expect(options['categories'].single['name'], 'Dynamic Category');
      expect(options['brands'].single['id'], 'brand-uuid');
      expect(options['models'].single['brandId'], 'brand-uuid');
      expect(options['models'].single['categoryId'], 'category-uuid');
      expect(options['years'], ['2026']);
    },
  );

  test('invalid manufacturing years do not produce a hardcoded year', () async {
    final controller = AuthController(
      authRepository: OptionsRepository(
        const Response(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'manufacturerYears': [
                {'year': 'invalid'},
                {'year': 2024},
              ],
            },
          },
        ),
      ),
    );
    final options = await controller.fetchVehicleOptions();
    expect(options['years'], ['2024']);
  });

  test(
    'failed API responses remain errors so the form can offer retry',
    () async {
      final repository = OptionsRepository(const Response(statusCode: 500));
      final controller = AuthController(authRepository: repository);
      await expectLater(controller.fetchVehicleOptions(), throwsStateError);
      repository.response = const Response(
        statusCode: 200,
        body: {'success': false, 'data': {}},
      );
      await expectLater(controller.fetchVehicleOptions(), throwsStateError);
    },
  );
}
