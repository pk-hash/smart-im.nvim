.PHONY: test
test:
	@chmod +x tests/run_tests.sh
	@tests/run_tests.sh

.PHONY: test-watch
test-watch:
	@echo "Watching for changes (Ctrl+C to stop)..."
	@while true; do \
		fswatch -1 -r lua/ tests/ 2>/dev/null || \
		inotifywait -q -r -e modify lua/ tests/ 2>/dev/null || \
		sleep 2; \
		clear; \
		make test || true; \
	done

.PHONY: clean
clean:
	@rm -rf .tests
	@echo "Cleaned test environment"
