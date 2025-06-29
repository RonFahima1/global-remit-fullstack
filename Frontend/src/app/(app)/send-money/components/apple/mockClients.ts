import { Client } from '../../hooks/useSendMoneyForm';

// Generate 20 mock clients for testing UI with many entries
export const mockClients: Client[] = [
  {
    id: '1',
    name: 'Alice Johnson',
    firstName: 'Alice',
    lastName: 'Johnson',
    idType: 'Passport',
    idNumber: 'P123456789',
    phone: '+1 (555) 123-4567',
    email: 'alice.johnson@example.com',
    country: 'United States',
    bankAccount: '12345678901234',
    status: 'Active',
    kycVerified: true,
    riskRating: 'Low',
  },
  {
    id: '2',
    name: 'Bob Smith',
    firstName: 'Bob',
    lastName: 'Smith',
    idType: 'Driver License',
    idNumber: 'DL987654321',
    phone: '+1 (555) 234-5678',
    email: 'bob.smith@example.com',
    country: 'United States',
    bankAccount: '23456789012345',
    status: 'Active',
    kycVerified: true,
    riskRating: 'Low',
  },
  {
    id: '3',
    name: 'Carlos Rodriguez',
    firstName: 'Carlos',
    lastName: 'Rodriguez',
    idType: 'National ID',
    idNumber: 'N12345678X',
    phone: '+34 612 345 678',
    email: 'carlos.rodriguez@example.com',
    country: 'Spain',
    bankAccount: 'ES9121000418450200051332',
    status: 'Active',
    kycVerified: true,
    riskRating: 'Low',
  },
  {
    id: '4',
    name: 'Diana Chen',
    firstName: 'Diana',
    lastName: 'Chen',
    idType: 'Passport',
    idNumber: 'P87654321',
    phone: '+86 135 1234 5678',
    email: 'diana.chen@example.com',
    country: 'China',
    bankAccount: '6212261001023778903',
    status: 'Active',
    kycVerified: true,
    riskRating: 'Low',
  },
  {
    id: '5',
    name: 'Emmanuel Okonkwo',
    firstName: 'Emmanuel',
    lastName: 'Okonkwo',
    idType: 'National ID',
    idNumber: 'NIG123456789',
    phone: '+234 801 234 5678',
    email: 'emmanuel.okonkwo@example.com',
    country: 'Nigeria',
    bankAccount: '0123456789',
    status: 'Active',
    kycVerified: false,
    riskRating: 'Medium',
  },
  {
    id: '6',
    firstName: 'Fatima',
    lastName: 'Al-Farsi',
    idType: 'Resident Card',
    idNumber: 'RC98765432',
    phone: '+971 50 123 4567',
    email: 'fatima.alfarsi@example.com',
  },
  {
    id: '7',
    firstName: 'George',
    lastName: 'Papadopoulos',
    idType: 'ID Card',
    idNumber: 'GR12345678',
    phone: '+30 690 123 4567',
    email: 'george.papadopoulos@example.com',
  },
  {
    id: '8',
    firstName: 'Hannah',
    lastName: 'Kim',
    idType: 'Passport',
    idNumber: 'P98761234',
    phone: '+82 10 1234 5678',
    email: 'hannah.kim@example.com',
  },
  {
    id: '9',
    firstName: 'Ibrahim',
    lastName: 'Nasser',
    idType: 'National ID',
    idNumber: 'EG29876543',
    phone: '+20 100 123 4567',
    email: 'ibrahim.nasser@example.com',
  },
  {
    id: '10',
    firstName: 'Julia',
    lastName: 'Müller',
    idType: 'ID Card',
    idNumber: 'DE987654321',
    phone: '+49 170 123 4567',
    email: 'julia.mueller@example.com',
  },
  {
    id: '11',
    firstName: 'Kenji',
    lastName: 'Tanaka',
    idType: 'Residence Card',
    idNumber: 'RC12345678J',
    phone: '+81 80 1234 5678',
    email: 'kenji.tanaka@example.com',
  },
  {
    id: '12',
    firstName: 'Layla',
    lastName: 'Hassan',
    idType: 'Passport',
    idNumber: 'P87654321L',
    phone: '+961 71 123 456',
    email: 'layla.hassan@example.com',
  },
  {
    id: '13',
    firstName: 'Miguel',
    lastName: 'Fernandez',
    idType: 'DNI',
    idNumber: '12345678Z',
    phone: '+34 612 345 678',
    email: 'miguel.fernandez@example.com',
  },
  {
    id: '14',
    firstName: 'Nina',
    lastName: 'Ivanova',
    idType: 'Passport',
    idNumber: 'P123456RU',
    phone: '+7 912 345 6789',
    email: 'nina.ivanova@example.com',
  },
  {
    id: '15',
    firstName: 'Omar',
    lastName: 'Khan',
    idType: 'CNIC',
    idNumber: '12345-1234567-1',
    phone: '+92 301 234 5678',
    email: 'omar.khan@example.com',
  },
  {
    id: '16',
    firstName: 'Priya',
    lastName: 'Patel',
    idType: 'Aadhaar',
    idNumber: '1234 5678 9012',
    phone: '+91 98765 43210',
    email: 'priya.patel@example.com',
  },
  {
    id: '17',
    firstName: 'Quan',
    lastName: 'Nguyen',
    idType: 'ID Card',
    idNumber: 'VN123456789',
    phone: '+84 91 234 56 78',
    email: 'quan.nguyen@example.com',
  },
  {
    id: '18',
    firstName: 'Rachel',
    lastName: 'Wilson',
    idType: 'Driver License',
    idNumber: 'DL123456789',
    phone: '+1 (555) 987-6543',
    email: 'rachel.wilson@example.com',
  },
  {
    id: '19',
    firstName: 'Samuel',
    lastName: 'Ortiz',
    idType: 'National ID',
    idNumber: 'MX98765432',
    phone: '+52 1 55 1234 5678',
    email: 'samuel.ortiz@example.com',
  },
  {
    id: '20',
    firstName: 'Talia',
    lastName: 'Cohen',
    idType: 'Passport',
    idNumber: 'P12345678IL',
    phone: '+972 50 123 4567',
    email: 'talia.cohen@example.com',
  }
];
