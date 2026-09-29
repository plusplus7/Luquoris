import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/services/service_providers.dart';

import 'support/fakes/fake_services.dart';

void main() {
  testWidgets('application smoke test', (tester) async {
    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: AppDependencies.test(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(
              FakeSessionRepository(),
            ),
          ],
        ),
        child: const LoquirisApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No meetings yet'), findsOneWidget);
  });
}
