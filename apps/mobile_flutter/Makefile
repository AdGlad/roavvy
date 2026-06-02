.PHONY: check test coverage

check: ## Run analysis and all tests
	flutter analyze 2>/tmp/analyze.txt && tail /tmp/analyze.txt
	flutter test

test: ## Run tests only
	flutter test

coverage: ## Generate HTML coverage report
	flutter test --coverage
	lcov --remove coverage/lcov.info \
	  '*/lib/**.g.dart' \
	  '*/lib/firebase_options.dart' \
	  '*/lib/**/*.freezed.dart' \
	  --output-file coverage/lcov_clean.info
	genhtml coverage/lcov_clean.info --output-directory coverage/html
	@echo "Coverage report: coverage/html/index.html"
