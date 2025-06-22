# Client Management System - Comprehensive Business Logic & Architecture Analysis

## Executive Summary

The Global Remit application is a **teller-based financial services platform** where tellers (bank employees) manage client transactions on behalf of customers. Clients do NOT log in directly - all operations are performed by tellers through a sophisticated web interface.

## 1. Business Model & Core Understanding

### 1.1 System Architecture Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Teller UI     │    │   Backend API   │    │   Database      │
│   (Next.js)     │◄──►│   (Go/Gin)      │◄──►│   (PostgreSQL)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Redis Cache   │    │   External      │    │   Audit Logs    │
│   (Session/Data)│    │   Integrations  │    │   (Compliance)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 1.2 User Roles & Permissions
- **ORG_ADMIN**: Full system access, user management, settings
- **AGENT_ADMIN**: Manages tellers, limited org settings
- **AGENT_USER**: Teller - processes transactions, views clients
- **COMPLIANCE_USER**: KYC approval, compliance reviews
- **ORG_USER**: Limited access, mostly view operations
- **GLOBAL_VIEWER**: Read-only access to everything

### 1.3 Core Business Flows
1. **Client Registration** → KYC Verification → Account Creation
2. **Transaction Processing** → Validation → Execution → Settlement
3. **Compliance Monitoring** → Risk Assessment → Approval/Rejection
4. **Reporting & Analytics** → Data Aggregation → Insights

## 2. Database Architecture & Data Flow

### 2.1 Core Schema Design

#### Authentication Schema (`auth.*`)
```sql
-- Users (Tellers/Staff)
auth.users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(20), -- Maps to roles table
    branch_id UUID,
    status VARCHAR(20),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

-- Role-Based Access Control
auth.roles (id, name, description, is_system)
auth.permissions (id, code, name, category)
auth.role_permissions (role_id, permission_id)
auth.user_roles (user_id, role_id)
```

#### Core Business Schema (`core.*`)
```sql
-- Client Master Data
core.clients (
    id UUID PRIMARY KEY,
    client_number VARCHAR(20) UNIQUE, -- Auto-generated: CL + YYMM + 8-digit ID
    client_type VARCHAR(20), -- 'INDIVIDUAL' | 'BUSINESS'
    status VARCHAR(20), -- 'PENDING' | 'ACTIVE' | 'SUSPENDED' | 'CLOSED'
    
    -- Personal Information
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- KYC/Compliance
    kyc_status VARCHAR(20), -- 'NOT_STARTED' | 'IN_PROGRESS' | 'VERIFIED' | 'REJECTED'
    risk_level VARCHAR(10), -- 'LOW' | 'MEDIUM' | 'HIGH'
    
    -- Business Logic
    branch_id UUID NOT NULL,
    relationship_manager_id UUID,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

-- Account Management
core.accounts (
    id UUID PRIMARY KEY,
    account_number VARCHAR(20) UNIQUE,
    client_id UUID REFERENCES core.clients(id),
    account_type VARCHAR(20), -- 'SAVINGS' | 'CURRENT' | 'BUSINESS'
    currency_code CHAR(3),
    balance DECIMAL(19,4),
    status VARCHAR(20),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

-- Transaction Processing
core.transactions (
    id UUID PRIMARY KEY,
    transaction_reference VARCHAR(50) UNIQUE,
    transaction_type_id UUID,
    status VARCHAR(20), -- 'pending' | 'completed' | 'failed' | 'cancelled'
    amount DECIMAL(20,4),
    currency_code CHAR(3),
    exchange_rate DECIMAL(20,10),
    fee_amount DECIMAL(20,4),
    net_amount DECIMAL(20,4),
    
    -- Business Context
    branch_id UUID,
    teller_id UUID REFERENCES auth.users(id),
    parent_transaction_id UUID, -- For complex transactions
    related_transaction_id UUID,
    
    -- Audit Trail
    created_by UUID,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
```

#### Compliance Schema (`compliance.*`)
```sql
-- KYC Verifications
compliance.kyc_verifications (
    id UUID PRIMARY KEY,
    client_id UUID REFERENCES core.clients(id),
    verification_type VARCHAR(50), -- 'ID_DOCUMENT' | 'ADDRESS_PROOF' | 'INCOME_PROOF'
    verification_status VARCHAR(20), -- 'pending' | 'approved' | 'rejected' | 'expired'
    verified_by UUID REFERENCES auth.users(id),
    verification_data JSONB,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

-- AML Checks
compliance.aml_checks (
    id UUID PRIMARY KEY,
    client_id UUID REFERENCES core.clients(id),
    transaction_id UUID REFERENCES core.transactions(id),
    check_type VARCHAR(50), -- 'SANCTIONS' | 'PEP' | 'RISK_SCORING'
    check_status VARCHAR(20), -- 'pending' | 'passed' | 'failed' | 'manual_review'
    risk_score INTEGER,
    risk_level VARCHAR(20), -- 'low' | 'medium' | 'high' | 'critical'
    check_data JSONB,
    resolved_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ
)

-- Audit Logging
compliance.audit_logs (
    id UUID PRIMARY KEY,
    event_time TIMESTAMPTZ,
    event_type VARCHAR(50),
    table_name VARCHAR(100),
    record_id UUID,
    user_id UUID REFERENCES auth.users(id),
    user_ip INET,
    action VARCHAR(20), -- 'INSERT' | 'UPDATE' | 'DELETE' | 'LOGIN' | 'LOGOUT'
    old_values JSONB,
    new_values JSONB
)
```

### 2.2 Data Relationships & Constraints

#### Client → Account → Transaction Flow
```
Client (1) ──► Account (1:N) ──► Transaction (1:N)
     │              │                    │
     │              │                    │
     ▼              ▼                    ▼
KYC Verification  Balance Updates    Audit Logs
Risk Assessment   Status Changes     Compliance Checks
```

#### Business Rules & Constraints
```sql
-- Client Validation Rules
CONSTRAINT chk_phone_format CHECK (phone ~* '^\\+?[0-9\\s-]+$')
CONSTRAINT chk_client_type CHECK (client_type IN ('INDIVIDUAL', 'BUSINESS'))
CONSTRAINT chk_kyc_status CHECK (kyc_status IN ('NOT_STARTED', 'IN_PROGRESS', 'VERIFIED', 'REJECTED'))

-- Transaction Validation Rules
CONSTRAINT chk_transaction_amount CHECK (amount > 0)
CONSTRAINT chk_net_amount CHECK (net_amount > 0)
CONSTRAINT chk_transaction_status CHECK (status IN ('pending', 'completed', 'failed', 'cancelled'))

-- Account Validation Rules
CONSTRAINT chk_account_balance CHECK (balance >= 0 OR account_type = 'BUSINESS')
```

## 3. Business Logic & Transaction Flows

### 3.1 Client Management Flow

#### Client Registration Process
```
1. Teller Initiates Registration
   ├── Basic Information Collection
   ├── ID Document Verification
   ├── Address Proof Collection
   └── Initial Risk Assessment

2. KYC Processing
   ├── Automated Document Validation
   ├── Sanctions Screening
   ├── PEP (Politically Exposed Person) Check
   └── Risk Score Calculation

3. Account Creation
   ├── Client Number Generation (CL + YYMM + 8-digit ID)
   ├── Default Account Creation
   ├── Initial Balance Setup
   └── Relationship Manager Assignment

4. Compliance Review
   ├── Manual Review (if required)
   ├── Additional Documentation Request
   ├── Approval/Rejection Decision
   └── Status Update
```

#### Client Search & Selection
```typescript
// Search Criteria
interface ClientSearch {
  byPhone?: string;        // Primary search method
  byName?: string;         // Fuzzy name search
  byClientNumber?: string; // Exact client number
  byIDNumber?: string;     // ID document number
}

// Search Results with Risk Indicators
interface ClientSearchResult {
  client: Client;
  riskLevel: 'LOW' | 'MEDIUM' | 'HIGH';
  kycStatus: 'VERIFIED' | 'PENDING' | 'REJECTED';
  recentTransactions: number;
  complianceFlags: string[];
  accountBalances: AccountBalance[];
}
```

### 3.2 Transaction Processing Flow

#### Money Transfer Process
```
1. Transaction Initiation
   ├── Sender Selection/Verification
   ├── Receiver Selection/Creation
   ├── Amount & Currency Specification
   └── Transfer Type Selection

2. Validation & Risk Assessment
   ├── Balance Verification
   ├── Transaction Limits Check
   ├── Compliance Screening
   ├── Exchange Rate Calculation
   └── Fee Structure Application

3. Transaction Execution
   ├── Account Debit (Sender)
   ├── Account Credit (Receiver)
   ├── Fee Deduction
   ├── Exchange Rate Application
   └── Transaction Reference Generation

4. Settlement & Confirmation
   ├── Real-time Settlement
   ├── Receipt Generation
   ├── SMS/Email Notification
   └── Audit Log Creation
```

#### Transaction Types & Business Rules
```typescript
// Transaction Type Definitions
enum TransactionType {
  REMITTANCE = 'remittance',    // Cross-border money transfer
  DEPOSIT = 'deposit',          // Cash/check deposit
  WITHDRAWAL = 'withdrawal',    // Cash withdrawal
  EXCHANGE = 'exchange',        // Currency exchange
  TRANSFER = 'transfer',        // Internal account transfer
  BILL_PAYMENT = 'bill_payment' // Utility/rent payment
}

// Business Rules by Transaction Type
interface TransactionRules {
  remittance: {
    maxAmount: number;
    requiresKYC: boolean;
    complianceChecks: string[];
    exchangeRateMargin: number;
    processingTime: string;
  };
  deposit: {
    maxAmount: number;
    acceptedCurrencies: string[];
    verificationRequired: boolean;
    holdPeriod: number;
  };
  withdrawal: {
    maxAmount: number;
    availableBalance: boolean;
    identificationRequired: boolean;
    dailyLimit: number;
  };
}
```

### 3.3 Compliance & Risk Management

#### KYC Verification Process
```typescript
// KYC Document Types
interface KYCDocument {
  type: 'PASSPORT' | 'NATIONAL_ID' | 'DRIVERS_LICENSE' | 'UTILITY_BILL' | 'BANK_STATEMENT';
  number: string;
  issueDate: Date;
  expiryDate: Date;
  issuingCountry: string;
  verificationStatus: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejectionReason?: string;
}

// Risk Assessment Algorithm
interface RiskAssessment {
  clientRiskScore: number;        // 0-100
  transactionRiskScore: number;   // 0-100
  overallRiskLevel: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  riskFactors: string[];
  recommendedAction: 'APPROVE' | 'REVIEW' | 'REJECT' | 'ESCALATE';
}
```

#### Compliance Monitoring
```typescript
// Real-time Compliance Checks
interface ComplianceCheck {
  sanctionsScreening: boolean;    // OFAC, UN, EU sanctions
  pepScreening: boolean;          // Politically Exposed Persons
  adverseMedia: boolean;          // Negative news screening
  transactionMonitoring: boolean; // Suspicious activity detection
  geographicRisk: boolean;        // High-risk countries
}

// Transaction Monitoring Rules
interface MonitoringRule {
  ruleType: 'AMOUNT_THRESHOLD' | 'FREQUENCY' | 'GEOGRAPHIC' | 'BEHAVIORAL';
  threshold: number;
  timeWindow: string;
  action: 'FLAG' | 'BLOCK' | 'REVIEW' | 'NOTIFY';
  description: string;
}
```

## 4. Frontend Architecture & User Experience

### 4.1 UI/UX Design Principles

#### iOS-Inspired Design System
```css
/* Color Palette */
:root {
  --primary-blue: #0A84FF;      /* iOS Blue */
  --secondary-blue: #5AC8FA;    /* iOS Light Blue */
  --success-green: #34C759;     /* iOS Green */
  --warning-orange: #FF9500;    /* iOS Orange */
  --danger-red: #FF3B30;        /* iOS Red */
  --background-gray: #F2F2F7;   /* iOS Light Gray */
  --text-dark: #000000;         /* iOS Dark Text */
}

/* Component Styling */
.card-ios {
  border-radius: 14px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  background: white;
  padding: 20px;
}

.button-ios-primary {
  background: var(--primary-blue);
  border-radius: 10px;
  color: white;
  font-weight: 600;
  padding: 12px 24px;
}
```

#### Responsive Design Patterns
```typescript
// Breakpoint Strategy
const breakpoints = {
  mobile: '320px',
  tablet: '768px',
  desktop: '1024px',
  wide: '1440px'
};

// Component Responsiveness
interface ResponsiveLayout {
  mobile: 'single-column' | 'stacked';
  tablet: 'two-column' | 'sidebar';
  desktop: 'multi-column' | 'dashboard';
}
```

### 4.2 User Interface Components

#### Dashboard Layouts by Role
```typescript
// Teller Dashboard
interface TellerDashboard {
  quickActions: QuickAction[];
  recentTransactions: Transaction[];
  clientSearch: ClientSearchWidget;
  balanceSummary: BalanceCard[];
  notifications: Notification[];
}

// Manager Dashboard
interface ManagerDashboard {
  teamOverview: TeamStats;
  branchPerformance: PerformanceMetrics;
  pendingApprovals: ApprovalItem[];
  complianceAlerts: ComplianceAlert[];
  reports: ReportSummary[];
}

// Compliance Dashboard
interface ComplianceDashboard {
  pendingReviews: KYCReview[];
  riskAlerts: RiskAlert[];
  auditLogs: AuditEntry[];
  complianceMetrics: ComplianceMetric[];
}
```

#### Transaction Flow UI
```typescript
// Multi-step Transaction Process
interface TransactionFlow {
  steps: TransactionStep[];
  currentStep: number;
  validation: StepValidation;
  navigation: StepNavigation;
}

interface TransactionStep {
  id: number;
  title: string;
  description: string;
  icon: ReactNode;
  isComplete: boolean;
  isActive: boolean;
  validation: ValidationRule[];
}
```

### 4.3 State Management & Data Flow

#### React Context Architecture
```typescript
// Global State Management
interface AppState {
  auth: AuthState;
  user: UserState;
  clients: ClientState;
  transactions: TransactionState;
  compliance: ComplianceState;
  notifications: NotificationState;
}

// Context Providers
const AppProviders = {
  AuthProvider: AuthContext.Provider,
  UserProvider: CurrentUserContext.Provider,
  NotificationProvider: NotificationContext.Provider,
  LanguageProvider: LanguageProvider,
  ThemeProvider: ThemeProvider
};
```

#### API Integration Patterns
```typescript
// Service Layer Pattern
interface APIService {
  clients: ClientService;
  transactions: TransactionService;
  compliance: ComplianceService;
  reports: ReportService;
}

// Hook-based Data Fetching
const useClientData = (clientId: string) => {
  return useQuery({
    queryKey: ['client', clientId],
    queryFn: () => clientService.getClient(clientId),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000  // 10 minutes
  });
};
```

## 5. Backend Services & API Architecture

### 5.1 Service Layer Design

#### Repository Pattern Implementation
```go
// Client Repository
type ClientRepository struct {
    db *sqlx.DB
    cache *redis.Client
}

func (r *ClientRepository) CreateClient(ctx context.Context, client *domain.Client) error {
    // 1. Validate business rules
    if err := r.validateClient(client); err != nil {
        return err
    }
    
    // 2. Generate client number
    client.ClientNumber = r.generateClientNumber()
    
    // 3. Insert into database
    if err := r.db.NamedExecContext(ctx, createClientQuery, client); err != nil {
        return err
    }
    
    // 4. Create default account
    if err := r.createDefaultAccount(ctx, client.ID); err != nil {
        return err
    }
    
    // 5. Cache client data
    r.cache.Set(ctx, fmt.Sprintf("client:%s", client.ID), client, time.Hour)
    
    return nil
}
```

#### Business Logic Services
```go
// Transaction Service
type TransactionService struct {
    clientRepo    *ClientRepository
    accountRepo   *AccountRepository
    complianceSvc *ComplianceService
    auditSvc      *AuditService
}

func (s *TransactionService) ProcessTransfer(ctx context.Context, req *TransferRequest) (*TransferResponse, error) {
    // 1. Validate request
    if err := s.validateTransferRequest(req); err != nil {
        return nil, err
    }
    
    // 2. Check compliance
    if err := s.complianceSvc.CheckTransaction(ctx, req); err != nil {
        return nil, err
    }
    
    // 3. Process transaction
    tx, err := s.accountRepo.ProcessTransfer(ctx, req)
    if err != nil {
        return nil, err
    }
    
    // 4. Audit logging
    s.auditSvc.LogTransaction(ctx, tx)
    
    return &TransferResponse{Transaction: tx}, nil
}
```

### 5.2 API Endpoint Design

#### RESTful API Structure
```go
// Client Management Endpoints
func (h *ClientHandler) RegisterRoutes(r *gin.RouterGroup) {
    clients := r.Group("/clients")
    {
        clients.POST("/", h.CreateClient)           // Create new client
        clients.GET("/", h.ListClients)             // List clients with filters
        clients.GET("/:id", h.GetClient)            // Get client details
        clients.PUT("/:id", h.UpdateClient)         // Update client
        clients.DELETE("/:id", h.DeleteClient)      // Soft delete client
        
        // Client-specific operations
        clients.POST("/:id/kyc", h.SubmitKYC)       // Submit KYC documents
        clients.GET("/:id/transactions", h.GetClientTransactions)
        clients.POST("/:id/accounts", h.CreateAccount)
    }
}

// Transaction Endpoints
func (h *TransactionHandler) RegisterRoutes(r *gin.RouterGroup) {
    transactions := r.Group("/transactions")
    {
        transactions.POST("/transfer", h.CreateTransfer)
        transactions.POST("/deposit", h.CreateDeposit)
        transactions.POST("/withdrawal", h.CreateWithdrawal)
        transactions.POST("/exchange", h.CreateExchange)
        transactions.GET("/:id", h.GetTransaction)
        transactions.GET("/", h.ListTransactions)
    }
}
```

#### Request/Response Models
```go
// Client Creation Request
type CreateClientRequest struct {
    ClientType    string    `json:"client_type" binding:"required,oneof=INDIVIDUAL BUSINESS"`
    FirstName     string    `json:"first_name" binding:"required,min=2,max=100"`
    LastName      string    `json:"last_name" binding:"required,min=2,max=100"`
    DateOfBirth   time.Time `json:"date_of_birth" binding:"required"`
    Email         string    `json:"email" binding:"required,email"`
    Phone         string    `json:"phone" binding:"required"`
    CountryCode   string    `json:"country_code" binding:"required,len=2"`
    
    // KYC Information
    IDType        string    `json:"id_type" binding:"required"`
    IDNumber      string    `json:"id_number" binding:"required"`
    IDIssueDate   time.Time `json:"id_issue_date" binding:"required"`
    IDExpiryDate  time.Time `json:"id_expiry_date" binding:"required"`
}

// Transaction Response
type TransferResponse struct {
    TransactionID    string    `json:"transaction_id"`
    Reference        string    `json:"reference"`
    Status           string    `json:"status"`
    Amount           float64   `json:"amount"`
    Currency         string    `json:"currency"`
    Fee              float64   `json:"fee"`
    ExchangeRate     float64   `json:"exchange_rate,omitempty"`
    ProcessedAt      time.Time `json:"processed_at"`
    ReceiptURL       string    `json:"receipt_url,omitempty"`
}
```

### 5.3 Middleware & Security

#### Authentication Middleware
```go
// JWT Authentication
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := extractToken(c)
        if token == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "No token provided"})
            c.Abort()
            return
        }
        
        claims, err := jwt.ValidateToken(token)
        if err != nil {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }
        
        // Set user context
        c.Set("user_id", claims.UserID)
        c.Set("user_role", claims.Role)
        c.Set("permissions", claims.Permissions)
        
        c.Next()
    }
}
```

#### Permission Middleware
```go
// Role-based Access Control
func RequirePermission(permission string) gin.HandlerFunc {
    return func(c *gin.Context) {
        permissions := c.MustGet("permissions").([]string)
        
        hasPermission := false
        for _, p := range permissions {
            if p == permission || p == "*:*" {
                hasPermission = true
                break
            }
        }
        
        if !hasPermission {
            c.JSON(http.StatusForbidden, gin.H{"error": "Insufficient permissions"})
            c.Abort()
            return
        }
        
        c.Next()
    }
}
```

## 6. Redis Caching Strategy

### 6.1 Cache Architecture
```go
// Cache Keys Structure
const (
    ClientCacheKey     = "client:%s"           // client:uuid
    AccountCacheKey    = "account:%s"          // account:uuid
    TransactionCacheKey = "transaction:%s"     // transaction:uuid
    UserSessionKey     = "session:%s"          // session:token
    ExchangeRateKey    = "rate:%s:%s"          // rate:USD:EUR
    ComplianceCheckKey = "compliance:%s"       // compliance:client_id
)

// Cache TTL Configuration
const (
    ClientTTL        = 1 * time.Hour
    AccountTTL       = 30 * time.Minute
    TransactionTTL   = 24 * time.Hour
    SessionTTL       = 8 * time.Hour
    ExchangeRateTTL  = 5 * time.Minute
    ComplianceTTL    = 1 * time.Hour
)
```

### 6.2 Cache Implementation
```go
// Cache Service
type CacheService struct {
    redis *redis.Client
}

func (c *CacheService) GetClient(ctx context.Context, clientID string) (*domain.Client, error) {
    key := fmt.Sprintf(ClientCacheKey, clientID)
    
    // Try cache first
    data, err := c.redis.Get(ctx, key).Result()
    if err == nil {
        var client domain.Client
        if err := json.Unmarshal([]byte(data), &client); err == nil {
            return &client, nil
        }
    }
    
    // Cache miss - fetch from database
    client, err := c.clientRepo.GetByID(ctx, clientID)
    if err != nil {
        return nil, err
    }
    
    // Cache the result
    if clientData, err := json.Marshal(client); err == nil {
        c.redis.Set(ctx, key, clientData, ClientTTL)
    }
    
    return client, nil
}
```

## 7. Integration & External Services

### 7.1 Payment Gateway Integration
```go
// Payment Gateway Interface
type PaymentGateway interface {
    ProcessTransfer(ctx context.Context, req *TransferRequest) (*TransferResponse, error)
    GetExchangeRate(ctx context.Context, from, to string) (float64, error)
    ValidateAccount(ctx context.Context, accountNumber string) (bool, error)
    GetTransactionStatus(ctx context.Context, reference string) (string, error)
}

// Multiple Gateway Support
type GatewayManager struct {
    gateways map[string]PaymentGateway
    config   *GatewayConfig
}

func (gm *GatewayManager) ProcessTransfer(ctx context.Context, req *TransferRequest) (*TransferResponse, error) {
    gateway := gm.selectGateway(req)
    return gateway.ProcessTransfer(ctx, req)
}
```

### 7.2 Compliance Service Integration
```go
// External Compliance Services
type ComplianceService struct {
    sanctionsAPI SanctionsAPI
    pepAPI       PEPAPI
    riskAPI      RiskAPI
}

func (cs *ComplianceService) CheckClient(ctx context.Context, client *domain.Client) (*ComplianceResult, error) {
    // Parallel compliance checks
    var wg sync.WaitGroup
    var sanctions, pep, risk interface{}
    var sanctionsErr, pepErr, riskErr error
    
    wg.Add(3)
    
    go func() {
        defer wg.Done()
        sanctions, sanctionsErr = cs.sanctionsAPI.Check(ctx, client)
    }()
    
    go func() {
        defer wg.Done()
        pep, pepErr = cs.pepAPI.Check(ctx, client)
    }()
    
    go func() {
        defer wg.Done()
        risk, riskErr = cs.riskAPI.Assess(ctx, client)
    }()
    
    wg.Wait()
    
    // Aggregate results
    return cs.aggregateResults(sanctions, pep, risk, sanctionsErr, pepErr, riskErr)
}
```

## 8. Testing Strategy

### 8.1 Test Architecture
```go
// Test Categories
type TestSuite struct {
    UnitTests      []UnitTest
    IntegrationTests []IntegrationTest
    E2ETests       []E2ETest
    PerformanceTests []PerformanceTest
}

// Unit Test Example
func TestClientService_CreateClient(t *testing.T) {
    // Arrange
    mockRepo := &MockClientRepository{}
    mockCompliance := &MockComplianceService{}
    service := NewClientService(mockRepo, mockCompliance)
    
    req := &CreateClientRequest{
        ClientType: "INDIVIDUAL",
        FirstName:  "John",
        LastName:   "Doe",
        // ... other fields
    }
    
    // Act
    client, err := service.CreateClient(context.Background(), req)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, client)
    assert.Equal(t, "John", client.FirstName)
    assert.Equal(t, "Doe", client.LastName)
}
```

### 8.2 E2E Testing
```typescript
// Playwright E2E Tests
describe('Client Management Flow', () => {
  test('should create new client and process transaction', async ({ page }) => {
    // Login as teller
    await page.goto('/login');
    await page.fill('[data-testid="email"]', 'teller@bank.com');
    await page.fill('[data-testid="password"]', 'password123');
    await page.click('[data-testid="login-button"]');
    
    // Navigate to client creation
    await page.click('[data-testid="new-client-button"]');
    
    // Fill client form
    await page.fill('[data-testid="first-name"]', 'John');
    await page.fill('[data-testid="last-name"]', 'Doe');
    await page.fill('[data-testid="phone"]', '+1234567890');
    await page.selectOption('[data-testid="id-type"]', 'passport');
    await page.fill('[data-testid="id-number"]', 'AB123456');
    
    // Submit form
    await page.click('[data-testid="submit-button"]');
    
    // Verify client created
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    
    // Process transaction
    await page.click('[data-testid="send-money-button"]');
    // ... continue with transaction flow
  });
});
```

## 9. Performance & Scalability

### 9.1 Database Optimization
```sql
-- Indexing Strategy
CREATE INDEX idx_clients_phone ON core.clients(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_clients_email ON core.clients(email) WHERE email IS NOT NULL;
CREATE INDEX idx_transactions_status_date ON core.transactions(status, created_at);
CREATE INDEX idx_transactions_teller_date ON core.transactions(teller_id, created_at);
CREATE INDEX idx_audit_logs_event_time ON compliance.audit_logs(event_time DESC);

-- Partitioning Strategy
CREATE TABLE core.transactions_2024 PARTITION OF core.transactions
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

### 9.2 Application Performance
```go
// Connection Pooling
func NewDatabaseConnection() (*sqlx.DB, error) {
    db, err := sqlx.Connect("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        return nil, err
    }
    
    // Configure connection pool
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)
    
    return db, nil
}

// Query Optimization
func (r *ClientRepository) SearchClients(ctx context.Context, query string) ([]*domain.Client, error) {
    // Use full-text search for better performance
    sql := `
        SELECT * FROM core.clients 
        WHERE to_tsvector('english', first_name || ' ' || last_name || ' ' || phone) @@ plainto_tsquery('english', $1)
        AND status = 'ACTIVE'
        ORDER BY ts_rank(to_tsvector('english', first_name || ' ' || last_name || ' ' || phone), plainto_tsquery('english', $1)) DESC
        LIMIT 50
    `
    
    var clients []*domain.Client
    err := r.db.SelectContext(ctx, &clients, sql, query)
    return clients, err
}
```

## 10. Security & Compliance

### 10.1 Security Measures
```go
// Input Validation
func validateClientInput(req *CreateClientRequest) error {
    // Phone number validation
    if !isValidPhoneNumber(req.Phone) {
        return errors.New("invalid phone number format")
    }
    
    // Age validation
    if time.Since(req.DateOfBirth) < 18*365*24*time.Hour {
        return errors.New("client must be at least 18 years old")
    }
    
    // ID number validation
    if !isValidIDNumber(req.IDNumber, req.IDType) {
        return errors.New("invalid ID number format")
    }
    
    return nil
}

// SQL Injection Prevention
func (r *ClientRepository) GetClientByPhone(ctx context.Context, phone string) (*domain.Client, error) {
    // Use parameterized queries
    var client domain.Client
    err := r.db.GetContext(ctx, &client, 
        "SELECT * FROM core.clients WHERE phone = $1 AND status = 'ACTIVE'", 
        phone)
    return &client, err
}
```

### 10.2 Audit Logging
```go
// Comprehensive Audit Trail
func (r *AuditService) LogClientAction(ctx context.Context, action string, clientID string, userID string, oldData, newData interface{}) error {
    auditLog := &domain.AuditLog{
        EventTime:  time.Now(),
        EventType:  "CLIENT_ACTION",
        TableName:  "core.clients",
        RecordID:   clientID,
        UserID:     userID,
        UserIP:     getClientIP(ctx),
        Action:     action,
        OldValues:  oldData,
        NewValues:  newData,
    }
    
    return r.repo.CreateAuditLog(ctx, auditLog)
}
```

## 11. Deployment & DevOps

### 11.1 Containerization
```dockerfile
# Backend Dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/api

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

### 11.2 Environment Configuration
```yaml
# docker-compose.yml
version: '3.8'
services:
  api:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/global_remit
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - db
      - redis
  
  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=global_remit
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

## 12. Monitoring & Observability

### 12.1 Application Metrics
```go
// Prometheus Metrics
var (
    clientCreationCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "client_creation_total",
            Help: "Total number of client creations",
        },
        []string{"status", "client_type"},
    )
    
    transactionDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "transaction_duration_seconds",
            Help:    "Transaction processing duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"transaction_type", "status"},
    )
)
```

### 12.2 Health Checks
```go
// Health Check Endpoints
func (h *HealthHandler) HealthCheck(c *gin.Context) {
    health := &HealthStatus{
        Status:    "healthy",
        Timestamp: time.Now(),
        Services:  make(map[string]ServiceStatus),
    }
    
    // Check database
    if err := h.db.Ping(); err != nil {
        health.Status = "unhealthy"
        health.Services["database"] = ServiceStatus{Status: "down", Error: err.Error()}
    } else {
        health.Services["database"] = ServiceStatus{Status: "up"}
    }
    
    // Check Redis
    if err := h.redis.Ping(); err != nil {
        health.Status = "unhealthy"
        health.Services["redis"] = ServiceStatus{Status: "down", Error: err.Error()}
    } else {
        health.Services["redis"] = ServiceStatus{Status: "up"}
    }
    
    c.JSON(http.StatusOK, health)
}
```

## Conclusion

This comprehensive analysis provides a complete understanding of the Global Remit client management system. The architecture follows modern best practices with:

1. **Clear separation of concerns** between frontend, backend, and database layers
2. **Role-based access control** ensuring proper security
3. **Comprehensive compliance** with KYC/AML requirements
4. **Scalable architecture** supporting high transaction volumes
5. **Modern UI/UX** with iOS-inspired design principles
6. **Robust testing** strategy covering all aspects
7. **Performance optimization** through caching and indexing
8. **Security measures** protecting sensitive financial data

The system is designed to handle the complex requirements of financial services while maintaining simplicity for teller users and ensuring compliance with regulatory requirements. 