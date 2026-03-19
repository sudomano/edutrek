const Map<String, List<String>> paymentMethodFields = {
  'cash': [
    'amount',
    'currency',
    'paymentDate',
  ],
  'mobile_money': [
    'amount',
    'currency',
    'provider',
    'phoneNumber',
    'reference',
    'paymentDate',
  ],
  'bank_transfer': [
    'amount',
    'currency',
    'provider',
    'accountNumber',
    'accountName',
    'reference',
    'paymentDate',
  ],
  'card': [
    'amount',
    'currency',
    'provider',
    'reference',
    'paymentDate',
  ],
  'cheque': [
    'amount',
    'currency',
    'accountName',
    'reference',
    'paymentDate',
  ],
  'voucher': [
    'amount',
    'currency',
    'reference',
  ],
  'other': [
    'amount',
    'currency',
    'provider',
    'reference',
  ],
};
