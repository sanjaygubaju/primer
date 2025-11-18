APP_NAME := primer
SRC_DIR  := .
BUILD_DIR := bin

# -------------------------
# Testing
# -------------------------
test:
	@echo "🧪 Running tests..."
	v test $(SRC_DIR)

# -------------------------
# Code formatting and linting
# -------------------------
fmt:
	@echo "🧹 Formatting source..."
	v fmt -w $(SRC_DIR)

check:
	@echo "🔍 Checking code for issues..."
	v vet $(SRC_DIR)

# -------------------------
# Clean build artifacts
# -------------------------
clean:
	@echo "🗑️  Cleaning up..."
	rm -rf $(BUILD_DIR)

docs:
	@echo "📖 Generating documentation..."
	v doc $(SRC_DIR)

# -------------------------
# Development workflow
# -------------------------
dev: fmt check test
	@echo "Development checks complete!"

# -------------------------
# Help command
# -------------------------
help:
	@echo "Available commands:"
	@echo "Testing:"
	@echo "  make test         - Run all *_test.v files"
	@echo ""
	@echo "Code quality:"
	@echo "  make fmt          - Format code using v fmt"
	@echo "  make check        - Run static analysis (v vet)"
	@echo "  make dev          - Run fmt + check + test"
	@echo ""
	@echo "Other:"
	@echo "  make clean        - Remove build directory"
	@echo "  make docs         - Generate documentation"

.PHONY: run build debug test test-verbose fmt check clean dev help
