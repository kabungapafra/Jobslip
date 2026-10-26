import '../models/client.dart';
import '../models/document.dart';
import '../models/line_item.dart';

/// The sample business, reachable only from "Load samples" in Setup. It
/// exists so the app can be shown — and its own screens sanity-checked —
/// without anyone having to type a day's paperwork in first.
///
/// Dates are relative to today rather than fixed, so the samples always
/// demonstrate the states that matter: one invoice genuinely overdue, one
/// still inside its terms, money collected recently. Hard-coded dates would
/// quietly turn the whole set overdue as months passed.
class SeedData {
  /// Sequence positions to continue from, so a sample run mints
  /// DGF-Q-0044, DGF-INV-0013 and DGF-R-0020 next.
  static const int quoteSeq = 43;
  static const int invoiceSeq = 12;
  static const int receiptSeq = 19;

  static DateTime _daysAgo(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - days);
  }

  static DateTime _plusDays(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days);

  static List<Client> clients() => [
    Client(
      id: 'c-nakawa',
      name: 'Nakawa Hardware',
      phone: '+256 701 445 902',
      location: 'Nakawa, Kampala',
    ),
    Client(
      id: 'c-brightstar',
      name: 'Bright Star Academy',
      phone: '+256 772 118 340',
      location: 'Kireka',
    ),
    Client(
      id: 'c-achieng',
      name: 'Mrs. Achieng',
      phone: '+256 758 620 117',
      location: 'Najjera Ph2',
    ),
    Client(
      id: 'c-kabalagala',
      name: 'Kabalagala Pharmacy',
      phone: '+256 704 991 226',
      location: 'Kabalagala',
    ),
    Client(id: 'c-gulu', name: 'Gulu Road Lodge', phone: '+256 782 330 415', location: 'Bwaise'),
  ];

  static List<LineItem> _networkJob(String prefix) => [
    LineItem(
      id: '$prefix-1',
      description: 'Router replacement (dual-band)',
      quantity: 1,
      unitPrice: 240000,
      unit: 'pcs',
      category: 'Networking',
    ),
    LineItem(
      id: '$prefix-2',
      description: 'Network re-configuration, per hour',
      quantity: 3,
      unitPrice: 60000,
      unit: 'hrs',
      category: 'Networking',
    ),
  ];

  static List<LineItem> _wifiJob(String prefix) => [
    LineItem(
      id: '$prefix-1',
      description: 'Wi-Fi access points, ceiling mount',
      quantity: 4,
      unitPrice: 210000,
      unit: 'pcs',
      category: 'Wi-Fi',
    ),
    LineItem(
      id: '$prefix-2',
      description: 'Site survey & setup',
      quantity: 1,
      unitPrice: 250000,
      unit: 'job',
      category: 'Wi-Fi',
    ),
  ];

  static List<DocumentModel> documents() {
    // ---- quotes ----
    final q43Date = _daysAgo(3);
    final q42Date = _daysAgo(1);
    final q41Date = _daysAgo(25);

    // ---- invoices ----
    final i12Date = _daysAgo(3);
    final i11Date = _daysAgo(23);
    final i10Date = _daysAgo(27);
    final i09Date = _daysAgo(40);
    final i10Paid = _daysAgo(15);
    final i09Paid = _daysAgo(29);

    return [
      // Still out for a decision, VAT charged.
      DocumentModel(
        id: 'd-q43',
        type: DocType.quotation,
        status: DocStatus.sent,
        number: 'DGF-Q-0043',
        date: q43Date,
        clientId: 'c-brightstar',
        clientName: 'Bright Star Academy',
        clientPhone: '+256 772 118 340',
        clientLocation: 'Kireka',
        vatEnabled: true,
        vatRate: 0.18,
        notes:
            'Wall drilling at the main block needs school permission. '
            'Power points to be provided by the client.',
        lines: [
          LineItem(
            id: 'q43-1',
            description: '4MP dome camera, indoor',
            quantity: 6,
            unitPrice: 185000,
            unit: 'pcs',
            category: 'Cameras',
          ),
          LineItem(
            id: 'q43-2',
            description: '8-channel NVR + 2TB drive',
            quantity: 1,
            unitPrice: 640000,
            unit: 'pcs',
            category: 'Cameras',
          ),
          LineItem(
            id: 'q43-3',
            description: 'Cat6 cable + trunking, per metre',
            quantity: 90,
            unitPrice: 4500,
            unit: 'm',
            category: 'Cabling',
          ),
          LineItem(
            id: 'q43-4',
            description: 'Installation & configuration',
            quantity: 1,
            unitPrice: 350000,
            unit: 'job',
            category: 'Labour',
          ),
        ],
      ),
      // Not sent yet.
      DocumentModel(
        id: 'd-q42',
        type: DocType.quotation,
        status: DocStatus.draft,
        number: 'DGF-Q-0042',
        date: q42Date,
        clientId: 'c-kabalagala',
        clientName: 'Kabalagala Pharmacy',
        clientPhone: '+256 704 991 226',
        clientLocation: 'Kabalagala',
        vatEnabled: false,
        vatRate: 0.18,
        lines: [
          LineItem(
            id: 'q42-1',
            description: 'SSD upgrade 500GB, fitted',
            quantity: 2,
            unitPrice: 320000,
            unit: 'pcs',
            category: 'Hardware',
          ),
          LineItem(
            id: 'q42-2',
            description: 'Windows reinstall + data transfer',
            quantity: 2,
            unitPrice: 90000,
            unit: 'pcs',
            category: 'Software',
          ),
        ],
      ),
      // Accepted, and the invoice that came out of it is the overdue one.
      DocumentModel(
        id: 'd-q41',
        type: DocType.quotation,
        status: DocStatus.invoiced,
        number: 'DGF-Q-0041',
        date: q41Date,
        clientId: 'c-nakawa',
        clientName: 'Nakawa Hardware',
        clientPhone: '+256 701 445 902',
        clientLocation: 'Nakawa, Kampala',
        vatEnabled: false,
        vatRate: 0.18,
        invoiceNumber: 'DGF-INV-0011',
        lines: _networkJob('q41'),
      ),

      // Inside its terms.
      DocumentModel(
        id: 'd-i12',
        type: DocType.invoice,
        status: DocStatus.unpaid,
        number: 'DGF-INV-0012',
        date: i12Date,
        clientId: 'c-achieng',
        clientName: 'Mrs. Achieng',
        clientPhone: '+256 758 620 117',
        clientLocation: 'Najjera Ph2',
        vatEnabled: false,
        vatRate: 0.18,
        dueDays: 14,
        dueDate: _plusDays(i12Date, 14),
        lines: [
          LineItem(
            id: 'i12-1',
            description: 'CCTV service call, 4 cameras',
            quantity: 1,
            unitPrice: 120000,
            unit: 'job',
          ),
          LineItem(
            id: 'i12-2',
            description: 'Outdoor bullet camera, replaced',
            quantity: 2,
            unitPrice: 165000,
            unit: 'pcs',
          ),
        ],
      ),
      // Past due — this is the one the home screen chases.
      DocumentModel(
        id: 'd-i11',
        type: DocType.invoice,
        status: DocStatus.unpaid,
        number: 'DGF-INV-0011',
        date: i11Date,
        clientId: 'c-nakawa',
        clientName: 'Nakawa Hardware',
        clientPhone: '+256 701 445 902',
        clientLocation: 'Nakawa, Kampala',
        vatEnabled: false,
        vatRate: 0.18,
        dueDays: 14,
        dueDate: _plusDays(i11Date, 14),
        fromNumber: 'DGF-Q-0041',
        lines: _networkJob('i11'),
      ),
      // Settled by mobile money, with its receipt.
      DocumentModel(
        id: 'd-i10',
        type: DocType.invoice,
        status: DocStatus.paid,
        number: 'DGF-INV-0010',
        date: i10Date,
        clientId: 'c-gulu',
        clientName: 'Gulu Road Lodge',
        clientPhone: '+256 782 330 415',
        clientLocation: 'Bwaise',
        vatEnabled: false,
        vatRate: 0.18,
        dueDays: 14,
        dueDate: _plusDays(i10Date, 14),
        paidOn: i10Paid,
        method: 'MTN MoMo',
        receiptNumber: 'DGF-R-0019',
        lines: _wifiJob('i10'),
      ),
      // Settled by bank transfer, VAT charged.
      DocumentModel(
        id: 'd-i09',
        type: DocType.invoice,
        status: DocStatus.paid,
        number: 'DGF-INV-0009',
        date: i09Date,
        clientId: 'c-brightstar',
        clientName: 'Bright Star Academy',
        clientPhone: '+256 772 118 340',
        clientLocation: 'Kireka',
        vatEnabled: true,
        vatRate: 0.18,
        dueDays: 14,
        dueDate: _plusDays(i09Date, 14),
        paidOn: i09Paid,
        method: 'Bank',
        lines: [
          LineItem(
            id: 'i09-1',
            description: 'Lab PCs - RAM upgrade 8GB',
            quantity: 12,
            unitPrice: 95000,
            unit: 'pcs',
          ),
        ],
      ),

      // The receipt for INV-0010.
      DocumentModel(
        id: 'd-r19',
        type: DocType.receipt,
        status: DocStatus.paid,
        number: 'DGF-R-0019',
        date: i10Paid,
        clientId: 'c-gulu',
        clientName: 'Gulu Road Lodge',
        clientPhone: '+256 782 330 415',
        clientLocation: 'Bwaise',
        vatEnabled: false,
        vatRate: 0.18,
        paidOn: i10Paid,
        method: 'MTN MoMo',
        fromNumber: 'DGF-INV-0010',
        lines: _wifiJob('r19'),
      ),
      // Paid on the spot, no invoice ever written.
      DocumentModel(
        id: 'd-r18',
        type: DocType.receipt,
        status: DocStatus.paid,
        number: 'DGF-R-0018',
        date: _daysAgo(7),
        clientId: 'c-kabalagala',
        clientName: 'Kabalagala Pharmacy',
        clientPhone: '+256 704 991 226',
        clientLocation: 'Kabalagala',
        vatEnabled: false,
        vatRate: 0.18,
        paidOn: _daysAgo(7),
        method: 'Cash',
        lines: [
          LineItem(
            id: 'r18-1',
            description: 'Printer driver fix & toner reset',
            quantity: 1,
            unitPrice: 70000,
            unit: 'job',
          ),
        ],
      ),
    ];
  }
}
