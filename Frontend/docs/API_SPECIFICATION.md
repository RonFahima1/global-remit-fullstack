# Global Remit API Specification

## Table of Contents
1. [Introduction](#introduction)
2. [Authentication](#authentication)
3. [Common Data Types](#common-data-types)
4. [Clients API](#clients-api)
   - [List/Search Clients](#list-search-clients)
   - [Get Client](#get-client)
   - [Create Client](#create-client)
   - [Update Client](#update-client)
   - [Client KYC Operations](#client-kyc-operations)
5. [Error Handling](#error-handling)
6. [Pagination](#pagination)
7. [Rate Limiting](#rate-limiting)

## Introduction

This document describes the RESTful API for the Global Remit application. The API follows REST principles and uses JSON for request/response payloads.

### Base URL
```
https://api.globalremit.com/v1
```

### Versioning
API versioning is done through the URL path. The current version is `v1`.

## Authentication

All API requests require authentication using JWT (JSON Web Tokens).

### Authentication Header
```
Authorization: Bearer <jwt_token>
```

### Required Scopes
- `clients:read` - Read access to client data
- `clients:write` - Write access to client data
- `clients:kyc` - Access to KYC operations

## Common Data Types

### Address
```typescript
interface Address {
  id: string;          // UUID
  type: 'home' | 'work' | 'billing' | 'shipping' | 'other';
  line1: string;
  line2?: string;
  city: string;
  state?: string;
  postalCode: string;
  country: string;     // ISO 3166-1 alpha-2 country code
  isPrimary: boolean;
  createdAt: string;   // ISO 8601 timestamp
  updatedAt: string;   // ISO 8601 timestamp
}
```

### Contact
```typescript
interface Contact {
  id: string;          // UUID
  type: 'email' | 'phone' | 'mobile' | 'fax' | 'other';
  value: string;
  isPrimary: boolean;
  notes?: string;
  verified: boolean;
  verifiedAt?: string; // ISO 8601 timestamp
  createdAt: string;   // ISO 8601 timestamp
  updatedAt: string;   // ISO 8601 timestamp
}
```

### Document
```typescript
interface Document {
  id: string;          // UUID
  type: 'id' | 'passport' | 'drivers_license' | 'utility_bill' | 'other';
  documentType: string;
  documentNumber: string;
  issueDate?: string;  // ISO 8601 date
  expiryDate?: string;  // ISO 8601 date
  issuingAuthority?: string;
  fileUrl?: string;
  status: 'pending' | 'verified' | 'rejected' | 'expired';
  rejectionReason?: string;
  verifiedBy?: string; // User ID
  verifiedAt?: string; // ISO 8601 timestamp
  createdAt: string;   // ISO 8601 timestamp
  updatedAt: string;   // ISO 8601 timestamp
}
```

### Client
```typescript
interface Client {
  id: string;          // UUID
  clientNumber: string;
  type: 'individual' | 'business';
  status: 'active' | 'inactive' | 'suspended' | 'under_review';
  
  // Personal Information
  firstName?: string;
  middleName?: string;
  lastName?: string;
  dateOfBirth?: string; // ISO 8601 date
  gender?: 'male' | 'female' | 'other' | 'prefer_not_to_say';
  
  // Business Information
  businessName?: string;
  businessType?: string;
  registrationNumber?: string;
  taxId?: string;
  
  // KYC Status
  kycStatus: 'not_started' | 'in_progress' | 'approved' | 'rejected';
  kycLevel: 'basic' | 'verified' | 'enhanced';
  
  // Relations
  addresses: Address[];
  contacts: Contact[];
  documents: Document[];
  
  // Metadata
  tags: string[];
  notes?: string;
  
  // System Fields
  createdAt: string;   // ISO 8601 timestamp
  updatedAt: string;   // ISO 8601 timestamp
  createdBy: string;   // User ID
  updatedBy?: string;  // User ID
  version: number;     // Optimistic concurrency control
}
```

## Clients API

### List/Search Clients

#### GET /clients

Returns a paginated list of clients based on search criteria.

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| q | string | No | Search query (searches in name, email, phone, client number) |
| status | string | No | Filter by status (comma-separated) |
| type | string | No | Filter by client type (individual, business) |
| kycStatus | string | No | Filter by KYC status |
| page | integer | No | Page number (default: 1) |
| limit | integer | No | Items per page (default: 20, max: 100) |
| sort | string | No | Sort field and direction (e.g., `createdAt:desc`) |

##### Response
```typescript
interface ClientListResponse {
  data: Client[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}
```

##### Example Request
```http
GET /clients?q=john&status=active&page=1&limit=10
Authorization: Bearer <jwt_token>
```

##### Example Response (200 OK)
```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "clientNumber": "CLT-2023-001",
      "type": "individual",
      "status": "active",
      "firstName": "John",
      "lastName": "Doe",
      "kycStatus": "approved",
      "kycLevel": "verified",
      "createdAt": "2023-01-15T10:30:00Z",
      "updatedAt": "2023-05-20T14:22:10Z"
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "limit": 10,
    "totalPages": 1
  }
}
```

### Get Client

#### GET /clients/{id}

Retrieves a single client by ID.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Client UUID |

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| include | string | No | Comma-separated related resources to include (e.g., `addresses,contacts,documents`) |

##### Response
```typescript
interface ClientResponse {
  data: Client;
}
```

##### Example Request
```http
GET /clients/550e8400-e29b-41d4-a716-446655440000?include=addresses,contacts
data: {"client":{"id":"550e8400-e29b-41d4-a716-446655440000","clientNumber":"CLT-2023-001","type":"individual","status":"active","firstName":"John","lastName":"Doe","dateOfBirth":"1985-05-15","gender":"male","kycStatus":"approved","kycLevel":"verified","addresses":[{"id":"660e8400-e29b-41d4-a716-446655440001","type":"home","line1":"123 Main St","city":"New York","state":"NY","postalCode":"10001","country":"US","isPrimary":true,"createdAt":"2023-01-15T10:30:00Z","updatedAt":"2023-01-15T10:30:00Z"}],"contacts":[{"id":"770e8400-e29b-41d4-a716-446655440002","type":"email","value":"john.doe@example.com","isPrimary":true,"verified":true,"verifiedAt":"2023-01-16T08:15:30Z","createdAt":"2023-01-15T10:30:00Z","updatedAt":"2023-01-16T08:15:30Z"},{"id":"880e8400-e29b-41d4-a716-446655440003","type":"mobile","value":"+1234567890","isPrimary":true,"verified":true,"verifiedAt":"2023-01-16T08:15:30Z","createdAt":"2023-01-15T10:30:00Z","updatedAt":"2023-01-16T08:15:30Z"}],"createdAt":"2023-01-15T10:30:00Z","updatedAt":"2023-05-20T14:22:10Z"}}
```

### Create Client

#### POST /clients

Creates a new client.

##### Request Body
```typescript
interface CreateClientRequest {
  type: 'individual' | 'business';
  
  // Individual fields
  firstName?: string;
  middleName?: string;
  lastName?: string;
  dateOfBirth?: string; // ISO 8601 date
  gender?: 'male' | 'female' | 'other' | 'prefer_not_to_say';
  
  // Business fields
  businessName?: string;
  businessType?: string;
  registrationNumber?: string;
  taxId?: string;
  
  // Initial addresses
  addresses?: Omit<Address, 'id' | 'createdAt' | 'updatedAt' | 'isPrimary'>[];
  
  // Initial contacts
  contacts?: Omit<Contact, 'id' | 'verified' | 'verifiedAt' | 'createdAt' | 'updatedAt'>[];
  
  // Initial documents
  documents?: Omit<Document, 'id' | 'status' | 'verifiedBy' | 'verifiedAt' | 'createdAt' | 'updatedAt'>[];
  
  // Metadata
  tags?: string[];
  notes?: string;
}
```

##### Response
```typescript
interface CreateClientResponse {
  data: Client;
  message: string;
}
```

##### Example Request
```http
POST /clients
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "type": "individual",
  "firstName": "John",
  "lastName": "Doe",
  "dateOfBirth": "1985-05-15",
  "gender": "male",
  "addresses": [
    {
      "type": "home",
      "line1": "123 Main St",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "US"
    }
  ],
  "contacts": [
    {
      "type": "email",
      "value": "john.doe@example.com",
      "isPrimary": true
    },
    {
      "type": "mobile",
      "value": "+1234567890",
      "isPrimary": true
    }
  ]
}
```

### Update Client

#### PATCH /clients/{id}

Updates an existing client.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Client UUID |

##### Request Body
```typescript
interface UpdateClientRequest {
  // All fields are optional
  firstName?: string;
  middleName?: string | null; // Set to null to clear
  lastName?: string;
  dateOfBirth?: string; // ISO 8601 date
  gender?: 'male' | 'female' | 'other' | 'prefer_not_to_say' | null;
  
  // Business fields
  businessName?: string | null;
  businessType?: string | null;
  registrationNumber?: string | null;
  taxId?: string | null;
  
  // Status
  status?: 'active' | 'inactive' | 'suspended' | 'under_review';
  
  // Metadata
  tags?: string[];
  notes?: string | null;
  
  // Version for optimistic concurrency
  version: number;
}
```

##### Response
```typescript
interface UpdateClientResponse {
  data: Client;
  message: string;
}
```

### Client KYC Operations

#### POST /clients/{id}/kyc/start

Initiates the KYC verification process for a client.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Client UUID |

##### Request Body
```typescript
interface StartKYCRequest {
  level: 'basic' | 'verified' | 'enhanced';
  provider?: string; // Optional KYC provider
}
```

##### Response
```typescript
interface StartKYCResponse {
  kycId: string;
  status: string;
  nextSteps: string[];
  providerData?: any;
}
```

## Receivers API

### List/Search Receivers

#### GET /receivers

Returns a paginated list of receivers, optionally filtered by client ID.

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| clientId | string | No | Filter by client ID |
| q | string | No | Search query (searches in name, email, phone) |
| country | string | No | Filter by country code |
| page | integer | No | Page number (default: 1) |
| limit | integer | No | Items per page (default: 20, max: 100) |

##### Response
```typescript
interface ReceiverListResponse {
  data: Receiver[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}
```

### Get Receiver

#### GET /receivers/{id}

Retrieves a single receiver by ID.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Receiver UUID |

##### Response
```typescript
interface ReceiverResponse {
  data: Receiver;
}

interface Receiver {
  id: string;          // UUID
  clientId?: string;    // Optional link to client
  type: 'individual' | 'business';
  status: 'active' | 'inactive';
  
  // Personal Information
  firstName?: string;
  middleName?: string;
  lastName?: string;
  
  // Business Information
  businessName?: string;
  
  // Contact Information
  email?: string;
  phoneNumber?: string;
  
  // Address
  address?: {
    line1?: string;
    line2?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country: string;  // ISO 3166-1 alpha-2
  };
  
  // Bank Details (for bank transfers)
  bankDetails?: {
    accountNumber: string;
    accountName: string;
    bankName: string;
    bankCode?: string;
    branchCode?: string;
    swiftCode?: string;
    iban?: string;
    currency?: string;  // ISO 4217
  };
  
  // Mobile Money (for mobile wallet transfers)
  mobileMoneyDetails?: {
    provider: string;
    phoneNumber: string;
    accountName?: string;
  };
  
  // Cash Pickup
  cashPickupDetails?: {
    locationName: string;
    locationCode?: string;
    address: string;
    city: string;
    country: string;
  };
  
  // Metadata
  tags: string[];
  notes?: string;
  isFavorite: boolean;
  
  // System Fields
  createdAt: string;   // ISO 8601 timestamp
  updatedAt: string;   // ISO 8601 timestamp
  createdBy: string;   // User ID
  updatedBy?: string;  // User ID
  version: number;     // Optimistic concurrency control
}
```

### Create Receiver

#### POST /receivers

Creates a new receiver.

##### Request Body
```typescript
interface CreateReceiverRequest {
  clientId?: string;    // Optional link to client
  type: 'individual' | 'business';
  
  // Personal Information
  firstName?: string;
  middleName?: string;
  lastName?: string;
  
  // Business Information
  businessName?: string;
  
  // Contact Information
  email?: string;
  phoneNumber?: string;
  
  // Address
  address?: {
    line1?: string;
    line2?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country: string;  // ISO 3166-1 alpha-2
  };
  
  // Payment Method Details (only one of these should be provided)
  bankDetails?: {
    accountNumber: string;
    accountName: string;
    bankName: string;
    bankCode?: string;
    branchCode?: string;
    swiftCode?: string;
    iban?: string;
    currency?: string;  // ISO 4217
  };
  
  mobileMoneyDetails?: {
    provider: string;
    phoneNumber: string;
    accountName?: string;
  };
  
  cashPickupDetails?: {
    locationName: string;
    locationCode?: string;
    address: string;
    city: string;
    country: string;
  };
  
  // Metadata
  tags?: string[];
  notes?: string;
  isFavorite?: boolean;
}
```

### Update Receiver

#### PATCH /receivers/{id}

Updates an existing receiver.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Receiver UUID |

##### Request Body
```typescript
interface UpdateReceiverRequest {
  // All fields are optional
  firstName?: string | null;
  middleName?: string | null;
  lastName?: string | null;
  businessName?: string | null;
  email?: string | null;
  phoneNumber?: string | null;
  
  address?: {
    line1?: string | null;
    line2?: string | null;
    city?: string | null;
    state?: string | null;
    postalCode?: string | null;
    country?: string | null;
  } | null;
  
  // Update payment method details (optional)
  bankDetails?: {
    accountNumber: string;
    accountName: string;
    bankName: string;
    bankCode?: string;
    branchCode?: string;
    swiftCode?: string;
    iban?: string;
    currency?: string;
  } | null;
  
  mobileMoneyDetails?: {
    provider: string;
    phoneNumber: string;
    accountName?: string;
  } | null;
  
  cashPickupDetails?: {
    locationName: string;
    locationCode?: string;
    address: string;
    city: string;
    country: string;
  } | null;
  
  // Metadata
  tags?: string[];
  notes?: string | null;
  isFavorite?: boolean;
  
  // Version for optimistic concurrency
  version: number;
}
```

### Link Receiver to Client

#### POST /receivers/{id}/link-client

Links a receiver to an existing client.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Receiver UUID |

##### Request Body
```typescript
interface LinkReceiverToClientRequest {
  clientId: string;  // The client UUID to link to
}
```

## Transactions API

### Get Transaction Quote

#### POST /transactions/quote

Gets a quote for a potential transaction without committing it.

##### Request Body
```typescript
interface GetQuoteRequest {
  // Transaction Details
  type: 'remittance' | 'deposit' | 'withdrawal' | 'transfer' | 'bill_payment';
  direction: 'outgoing' | 'incoming';
  
  // Amount Information
  amount: number;
  sourceCurrency: string;  // ISO 4217
  targetCurrency: string;  // ISO 4217
  
  // Parties
  sourceAccountId?: string;  // Required for outgoing transactions
  destinationAccountId?: string;  // For internal transfers
  
  // For remittances
  receiverId?: string;
  receiverDetails?: {
    // Same as receiver creation fields
    type: 'individual' | 'business';
    firstName?: string;
    lastName?: string;
    businessName?: string;
    
    // Payment method details (one of these is required if not using receiverId)
    bankDetails?: {
      accountNumber: string;
      accountName: string;
      bankName: string;
      bankCode?: string;
      swiftCode?: string;
      iban?: string;
    };
    
    mobileMoneyDetails?: {
      provider: string;
      phoneNumber: string;
    };
    
    cashPickupDetails?: {
      locationName: string;
      locationCode?: string;
      country: string;
    };
  };
  
  // Additional metadata
  purposeOfTransfer?: string;
  sourceOfFunds?: string;
  
  // For scheduled transactions
  scheduleFor?: string;  // ISO 8601 timestamp
}
```

##### Response
```typescript
interface QuoteResponse {
  quoteId: string;  // UUID for this quote
  expiresAt: string;  // ISO 8601 timestamp
  
  // Amount Details
  sourceAmount: number;
  sourceCurrency: string;
  targetAmount: number;
  targetCurrency: string;
  exchangeRate: number;
  
  // Fees
  fees: {
    serviceFee: number;
    fxFee: number;
    totalFees: number;
    taxAmount: number;
    totalAmount: number;  // sourceAmount + totalFees + taxAmount
  };
  
  // Estimated Delivery
  estimatedDelivery: {
    minHours: number;
    maxHours: number;
    cutoffTime: string;  // ISO 8601 time (HH:MM:SS) for same-day processing
  };
  
  // Compliance Information
  compliance: {
    requiresAdditionalInfo: boolean;
    requiredDocuments?: string[];
    limits: {
      remainingDaily: number;
      remainingMonthly: number;
      limitType: 'individual' | 'business';
    };
  };
}
```

### Create Transaction

#### POST /transactions

Creates and processes a new transaction based on a quote.

##### Request Body
```typescript
interface CreateTransactionRequest {
  quoteId: string;  // From the quote endpoint
  
  // Additional information that might be required
  additionalInfo?: {
    [key: string]: any;
  };
  
  // For compliance
  purposeOfTransfer?: string;
  sourceOfFunds?: string;
  
  // For notifications
  sendNotifications: boolean;
  notificationPreferences?: {
    email?: boolean;
    sms?: boolean;
    push?: boolean;
  };
  
  // For tracking
  reference?: string;  // External reference
  metadata?: {
    [key: string]: string;
  };
}
```

##### Response
```typescript
interface TransactionResponse {
  transactionId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled' | 'requires_attention';
  statusMessage?: string;
  
  // Transaction Details
  type: string;
  direction: 'incoming' | 'outgoing';
  amount: number;
  currency: string;
  
  // For outgoing transactions
  fees?: {
    serviceFee: number;
    fxFee: number;
    totalFees: number;
    taxAmount: number;
    totalAmount: number;
  };
  
  // For remittances
  exchangeRate?: number;
  targetAmount?: number;
  targetCurrency?: string;
  
  // Parties
  sourceAccountId?: string;
  destinationAccountId?: string;
  receiverId?: string;
  
  // Timestamps
  createdAt: string;  // ISO 8601
  updatedAt: string;  // ISO 8601
  
  // For scheduled transactions
  scheduledFor?: string;  // ISO 8601
  
  // For tracking
  reference?: string;
  
  // Next steps if action is required
  nextSteps?: string[];
  
  // Version for optimistic concurrency
  version: number;
}
```

### Get Transaction Status

#### GET /transactions/{id}

Retrieves the current status and details of a transaction.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Transaction UUID |

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| include | string | No | Comma-separated related resources to include (e.g., `events,documents`) |

##### Response
```typescript
interface TransactionStatusResponse {
  data: {
    transaction: TransactionResponse;
    
    // Additional included resources
    events?: TransactionEvent[];
    documents?: TransactionDocument[];
    complianceChecks?: ComplianceCheck[];
  };
}

interface TransactionEvent {
  id: string;
  type: 'created' | 'status_changed' | 'compliance_check' | 'document_uploaded' | 'completed' | 'failed' | 'cancelled';
  status: string;
  message: string;
  metadata?: any;
  createdAt: string;  // ISO 8601
  createdBy?: string;  // User ID or system
}

interface TransactionDocument {
  id: string;
  type: string;
  name: string;
  url: string;
  status: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  uploadedAt: string;  // ISO 8601
  uploadedBy: string;  // User ID
}

interface ComplianceCheck {
  checkType: string;
  status: 'pending' | 'passed' | 'failed' | 'manual_review';
  checkedAt?: string;  // ISO 8601
  checkedBy?: string;  // User ID or system
  notes?: string;
}
```

### List Transactions

#### GET /transactions

Retrieves a paginated list of transactions with filtering options.

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| clientId | string | No | Filter by client ID |
| accountId | string | No | Filter by account ID |
| type | string | No | Filter by transaction type |
| status | string | No | Filter by status (comma-separated) |
| direction | string | No | 'incoming' or 'outgoing' |
| fromDate | string | No | Start date (ISO 8601) |
| toDate | string | No | End date (ISO 8601) |
| minAmount | number | No | Minimum amount |
| maxAmount | number | No | Maximum amount |
| currency | string | No | Filter by currency |
| q | string | No | Search in reference, description, etc. |
| sort | string | No | Sort field and direction (e.g., 'createdAt:desc') |
| page | number | No | Page number (default: 1) |
| limit | number | No | Items per page (default: 20, max: 100) |

##### Response
```typescript
interface TransactionListResponse {
  data: TransactionResponse[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
  summary?: {
    totalAmount: number;
    totalFees: number;
    count: number;
  };
}
```

### Cancel Transaction

#### POST /transactions/{id}/cancel

Attempts to cancel a pending transaction.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Transaction UUID |

##### Request Body
```typescript
interface CancelTransactionRequest {
  reason?: string;
  version: number;  // For optimistic concurrency
}
```

## Accounts API

### List Accounts

#### GET /accounts

Retrieves a paginated list of accounts with optional filtering.

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| clientId | string | No | Filter by client ID |
| type | string | No | Filter by account type (e.g., 'checking', 'savings') |
| status | string | No | Filter by status (comma-separated) |
| currency | string | No | Filter by currency code |
| q | string | No | Search in account name, number, etc. |
| include | string | No | Comma-separated related resources to include (e.g., 'balance,client') |
| page | number | No | Page number (default: 1) |
| limit | number | No | Items per page (default: 20, max: 100) |
| sort | string | No | Sort field and direction (e.g., 'balance:desc') |

##### Response
```typescript
interface AccountListResponse {
  data: Account[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}

interface Account {
  id: string;  // UUID
  accountNumber: string;
  clientId: string;
  type: 'checking' | 'savings' | 'business' | 'vostro' | 'nostro' | 'suspense' | 'commission' | 'fee' | 'tax' | 'settlement';
  subtype?: string;
  currency: string;  // ISO 4217
  status: 'active' | 'inactive' | 'dormant' | 'closed' | 'blocked' | 'under_review';
  
  // Account Details
  name: string;
  description?: string;
  
  // Balance Information
  balance: {
    available: number;
    current: number;
    pending: number;
    hold: number;
    overdraftLimit?: number;
    creditLimit?: number;
    lastUpdated: string;  // ISO 8601
  };
  
  // Interest Information
  interest?: {
    rate: number;  // Annual interest rate
    accrual: 'daily' | 'monthly' | 'quarterly' | 'annually';
    nextAccrualDate?: string;  // ISO 8601
    lastAccrualDate?: string;  // ISO 8601
    ytdInterestPaid: number;
  };
  
  // Account Features
  features: {
    allowsPayments: boolean;
    allowsDeposits: boolean;
    allowsWithdrawals: boolean;
    allowsTransfers: boolean;
    allowsBillPay: boolean;
    allowsCardTransactions: boolean;
    hasOverdraft: boolean;
    isInterestBearing: boolean;
    isTaxable: boolean;
    isJointAccount: boolean;
  };
  
  // Account Settings
  settings: {
    minimumBalance: number;
    minimumDeposit: number;
    withdrawalLimit: number;
    dailyLimit: number;
    monthlyLimit: number;
    transactionLimit: number;
    allowInternational: boolean;
    allowForeignCurrency: boolean;
    statementCycle: 'monthly' | 'quarterly' | 'semi_annually' | 'annually';
    statementDelivery: 'paper' | 'electronic' | 'both';
  };
  
  // Dates
  openedAt: string;  // ISO 8601
  lastActivityAt?: string;  // ISO 8601
  closedAt?: string;  // ISO 8601
  
  // Relationships
  owners: AccountOwner[];
  authorizedSigners: AuthorizedSigner[];
  
  // Metadata
  tags: string[];
  metadata?: {
    [key: string]: any;
  };
  
  // System Fields
  createdAt: string;  // ISO 8601
  updatedAt: string;  // ISO 8601
  createdBy: string;  // User ID
  updatedBy?: string;  // User ID
  version: number;    // For optimistic concurrency
}

interface AccountOwner {
  clientId: string;
  type: 'primary' | 'joint' | 'beneficiary' | 'power_of_attorney' | 'trustee' | 'other';
  ownershipPercentage?: number;  // For joint accounts
  relationship?: string;
  addedAt: string;  // ISO 8601
  addedBy: string;  // User ID
}

interface AuthorizedSigner {
  clientId: string;
  name: string;
  permissions: string[];  // e.g., ['withdraw', 'deposit', 'view', 'manage']
  addedAt: string;  // ISO 8601
  addedBy: string;  // User ID
  expiresAt?: string;  // ISO 8601
}
```

### Get Account Details

#### GET /accounts/{id}

Retrieves detailed information about a specific account.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Account UUID or account number |

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| include | string | No | Comma-separated related resources to include (e.g., 'balance,transactions,holds') |

##### Response
```typescript
interface AccountResponse {
  data: Account;
  included?: {
    transactions?: Transaction[];
    holds?: Hold[];
    statements?: Statement[];
    client?: Client;
  };
}
```

### Get Account Balance

#### GET /accounts/{id}/balance

Retrieves the current balance information for an account.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Account UUID or account number |

##### Response
```typescript
interface AccountBalanceResponse {
  accountId: string;
  accountNumber: string;
  currency: string;
  balances: {
    available: number;
    current: number;
    pending: number;
    hold: number;
    overdraftLimit?: number;
    creditLimit?: number;
    effectiveBalance: number;  // current - hold
    availableBalance: number;  // available - hold
  };
  lastUpdated: string;  // ISO 8601
}
```

### List Account Transactions

#### GET /accounts/{id}/transactions

Retrieves a paginated list of transactions for a specific account.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Account UUID or account number |

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| startDate | string | No | Start date (ISO 8601) |
| endDate | string | No | End date (ISO 8601) |
| type | string | No | Filter by transaction type |
| status | string | No | Filter by status (comma-separated) |
| minAmount | number | No | Minimum amount |
| maxAmount | number | No | Maximum amount |
| reference | string | No | Filter by reference |
| category | string | No | Filter by category |
| q | string | No | Search in description, reference, etc. |
| page | number | No | Page number (default: 1) |
| limit | number | No | Items per page (default: 20, max: 100) |
| sort | string | No | Sort field and direction (e.g., 'date:desc') |

##### Response
```typescript
interface AccountTransactionsResponse {
  data: Transaction[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
  summary?: {
    totalCredits: number;
    totalDebits: number;
    netChange: number;
    startBalance: number;
    endBalance: number;
  };
}
```

### Get Account Statement

#### GET /accounts/{id}/statements/{statementId}

Retrieves a specific account statement.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Account UUID or account number |
| statementId | string | Yes | Statement ID |

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| format | string | No | Response format: 'json' or 'pdf' (default: 'json') |

##### Response
For JSON format:
```typescript
interface AccountStatementResponse {
  id: string;
  accountId: string;
  accountNumber: string;
  statementNumber: string;
  period: {
    start: string;  // ISO 8601
    end: string;    // ISO 8601
  };
  openingBalance: number;
  closingBalance: number;
  totalCredits: number;
  totalDebits: number;
  fees: number;
  interestEarned: number;
  interestCharged: number;
  transactions: Transaction[];
  generatedAt: string;  // ISO 8601
  nextStatementDate?: string;  // ISO 8601
}
```

For PDF format, returns the statement as a PDF document.

### List Account Holds

#### GET /accounts/{id}/holds

Retrieves a list of holds (locks) on an account's balance.

##### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Account UUID or account number |

##### Query Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| status | string | No | Filter by status: 'active', 'released', 'expired' |
| type | string | No | Filter by hold type |
| startDate | string | No | Filter by start date (ISO 8601) |
| endDate | string | No | Filter by end date (ISO 8601) |
| page | number | No | Page number (default: 1) |
| limit | number | No | Items per page (default: 20, max: 100) |

##### Response
```typescript
interface AccountHoldsResponse {
  data: Hold[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
  summary: {
    totalHeld: number;
    activeHolds: number;
  };
}

interface Hold {
  id: string;
  accountId: string;
  type: 'authorization' | 'block' | 'legal' | 'dispute' | 'other';
  status: 'active' | 'released' | 'expired';
  amount: number;
  currency: string;
  reference: string;
  description?: string;
  metadata?: {
    [key: string]: any;
  };
  expiresAt?: string;  // ISO 8601
  releasedAt?: string;  // ISO 8601
  releasedBy?: string;  // User ID
  createdAt: string;    // ISO 8601
  createdBy: string;    // User ID
  transactionId?: string;
}
```

## Error Handling

### Error Response
```typescript
interface ErrorResponse {
  error: {
    code: string;
    message: string;
    details?: any;
    requestId: string;
    timestamp: string;
  };
}
```

### Common Error Codes
| Code | Status | Description |
|------|--------|-------------|
| invalid_request | 400 | Invalid request parameters |
| unauthorized | 401 | Authentication required |
| forbidden | 403 | Insufficient permissions |
| not_found | 404 | Resource not found |
| conflict | 409 | Resource conflict (e.g., version mismatch) |
| too_many_requests | 429 | Rate limit exceeded |
| internal_error | 500 | Internal server error |
| service_unavailable | 503 | Service temporarily unavailable |

## Pagination

All list endpoints support pagination using the following query parameters:
- `page`: Page number (1-based)
- `limit`: Number of items per page (default: 20, max: 100)

Pagination metadata is included in the response:
```typescript
{
  "data": [],
  "pagination": {
    "total": 100,
    "page": 1,
    "limit": 20,
    "totalPages": 5
  }
}
```

## Rate Limiting

API requests are subject to rate limiting. The following headers are included in rate-limited responses:

| Header | Description |
|--------|-------------|
| X-RateLimit-Limit | The maximum number of requests allowed in the current period |
| X-RateLimit-Remaining | The number of requests remaining in the current period |
| X-RateLimit-Reset | The time at which the current rate limit window resets (UTC epoch seconds) |

### Default Rate Limits
- **Unauthenticated:** 60 requests per minute
- **Authenticated:** 1000 requests per minute
- **Per Client:** 100 requests per minute

---

*Document generated on: 2025-06-20*
