# Contributing to Global Remit

Thank you for your interest in contributing to Global Remit! This document outlines the process for contributing to our project.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Code Review Guidelines](#code-review-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Security](#security)
- [Community](#community)

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before making any contributions.

## Getting Started

### Prerequisites
- Go 1.21+
- Node.js 18+ (for frontend development)
- Docker and Docker Compose
- Git 2.30+

### Setting Up Your Development Environment

1. **Fork the Repository**
   - Click the "Fork" button on the GitHub repository
   - Clone your fork locally:
     ```bash
     git clone https://github.com/your-username/global-remit.git
     cd global-remit
     ```

2. **Set Up Git Remote**
   ```bash
   git remote add upstream https://github.com/organization/global-remit.git
   ```

3. **Install Dependencies**
   ```bash
   # Install Go dependencies
   make deps
   
   # Install frontend dependencies
   cd frontend && npm install
   ```

4. **Set Up Environment Variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Start Development Services**
   ```bash
   # Start database and other services
   docker compose up -d
   
   # Run database migrations
   make migrate-up
   
   # Start the development server
   make dev
   ```

## Development Workflow

### Branch Naming Convention
Use the following prefixes for your branches:
- `feature/`: New features or enhancements
- `bugfix/`: Bug fixes
- `hotfix/`: Critical production fixes
- `chore/`: Maintenance tasks
- `docs/`: Documentation updates
- `refactor/`: Code refactoring

Example: `feature/add-user-authentication`

### Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or modifying tests
- `chore`: Changes to the build process or auxiliary tools

Example:
```
feat(auth): add JWT authentication

- Implement JWT token generation
- Add authentication middleware
- Update user model with password hashing

Closes #123
```

### Keeping Your Fork Updated

```bash
# Fetch changes from upstream
git fetch upstream

# Merge changes from main branch
git checkout main
git merge upstream/main

# Update your feature branch
git checkout your-feature-branch
git merge main
```

## Coding Standards

### Go Coding Standards

1. **Formatting**
   - Use `go fmt` and `goimports`
   - Maximum line length: 120 characters
   - Use `golangci-lint` for static analysis

2. **Naming Conventions**
   - Use `camelCase` for variables and functions
   - Use `PascalCase` for exported names
   - Use `UPPER_SNAKE_CASE` for constants
   - Prefix interface names with `I` only if necessary

3. **Error Handling**
   - Always check errors
   - Use `errors.New()` or `fmt.Errorf()`
   - Wrap errors with context using `fmt.Errorf("%w", err)`
   - Define sentinel errors with `var`

4. **Testing**
   - Use table-driven tests
   - Test files end with `_test.go`
   - Test functions start with `Test`
   - Use test helpers for common setup/teardown

### Frontend Coding Standards

1. **TypeScript**
   - Use TypeScript for all new code
   - Enable strict mode
   - Use interfaces over types when possible
   - Avoid `any` type

2. **React**
   - Use functional components with hooks
   - Keep components small and focused
   - Use PropTypes or TypeScript interfaces for props
   - Prefer named exports

## Pull Request Process

1. **Before Submitting a PR**
   - Ensure tests pass: `make test`
   - Run linters: `make lint`
   - Update documentation if needed
   - Rebase on the latest `main` branch

2. **Creating a PR**
   - Push your branch to your fork
   - Open a PR against the `main` branch
   - Fill out the PR template
   - Link any related issues

3. **PR Review Process**
   - At least one approval required
   - All CI checks must pass
   - Address all review comments
   - Update documentation if needed

## Code Review Guidelines

### As a Reviewer
- Be constructive and respectful
- Focus on the code, not the person
- Explain the "why" behind requested changes
- Suggest improvements when possible

### As a Contributor
- Be open to feedback
- Ask questions if something is unclear
- Keep discussions focused on the code
- Be responsive to review comments

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests
make test-integration

# Run e2e tests
make test-e2e

# Run tests with coverage
make test-coverage
```

### Writing Tests
- Follow the Arrange-Act-Assert pattern
- Test both success and error cases
- Use table-driven tests for similar test cases
- Mock external dependencies
- Keep tests independent and isolated

## Documentation

### Updating Documentation
- Update documentation when adding new features
- Keep API documentation in sync with code
- Use clear, concise language
- Include examples where helpful

### Documentation Style
- Use Markdown format
- Follow the existing style and structure
- Use proper headings and formatting
- Include code examples with syntax highlighting

## Security

### Reporting Security Issues

If you discover a security vulnerability, please report it by emailing security@globalremit.com. Do not create a public GitHub issue.

### Security Best Practices
- Never commit sensitive information
- Use environment variables for configuration
- Validate all user input
- Use prepared statements for database queries
- Keep dependencies up to date

## Community

### Getting Help
- Check the [documentation](https://docs.globalremit.com)
- Join our [Slack workspace](https://globalremit.slack.com)
- Ask questions in the #help channel

### Becoming a Maintainer
- Consistently contribute high-quality code
- Help review pull requests
- Participate in discussions
- Show responsibility and good judgment

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

*Last updated: June 20, 2025*
