import '../models/client.dart';
import '../models/document.dart';
import '../models/line_item.dart';

class SeedData {
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
          name: 'Mrs. Achieng (home)',
          phone: '+256 758 620 117',
          location: 'Najjera Ph2',
        ),
        Client(
          id: 'c-kabalagala',
          name: 'Kabalagala Pharmacy',
          phone: '+256 704 991 226',
          location: 'Kabalagala',
        ),
      ];

  static List<DocumentModel> documents() => [
        DocumentModel(
          id: 'd-0042',
          type: DocType.quotation,
          status: DocStatus.sent,
          number: 'DGF-Q-0042',
          date: DateTime(2026, 8, 2),
          clientId: 'c-brightstar',
          clientName: 'Bright Star Academy',
          clientPhone: '+256 772 118 340',
          clientLocation: 'Kireka',
          vatEnabled: true,
          vatRate: 0.18,
          lines: [
            LineItem(id: 'l1', description: '4MP dome camera, indoor', quantity: 6, unitPrice: 185000),
            LineItem(id: 'l2', description: '8-channel NVR + 2TB drive', quantity: 1, unitPrice: 640000),
            LineItem(id: 'l3', description: 'Cat6 cable + trunking run', quantity: 90, unitPrice: 4500),
            LineItem(id: 'l4', description: 'Installation & configuration', quantity: 1, unitPrice: 350000),
          ],
        ),
        DocumentModel(
          id: 'd-0018',
          type: DocType.receipt,
          status: DocStatus.paid,
          number: 'DGF-R-0018',
          date: DateTime(2026, 7, 29),
          clientId: 'c-nakawa',
          clientName: 'Nakawa Hardware',
          clientPhone: '+256 701 445 902',
          clientLocation: 'Nakawa, Kampala',
          vatEnabled: false,
          vatRate: 0.18,
          lines: [
            LineItem(id: 'l5', description: 'Router replacement (dual-band)', quantity: 1, unitPrice: 240000),
            LineItem(id: 'l6', description: 'Network re-configuration, 3 hrs', quantity: 3, unitPrice: 60000),
          ],
        ),
        DocumentModel(
          id: 'd-0041',
          type: DocType.quotation,
          status: DocStatus.draft,
          number: 'DGF-Q-0041',
          date: DateTime(2026, 7, 26),
          clientId: 'c-kabalagala',
          clientName: 'Kabalagala Pharmacy',
          clientPhone: '+256 704 991 226',
          clientLocation: 'Kabalagala',
          vatEnabled: false,
          vatRate: 0.18,
          lines: [
            LineItem(id: 'l7', description: 'PC diagnosis & SSD upgrade (500GB)', quantity: 2, unitPrice: 320000),
            LineItem(id: 'l8', description: 'Windows reinstall + data transfer', quantity: 2, unitPrice: 90000),
          ],
        ),
        DocumentModel(
          id: 'd-0017',
          type: DocType.receipt,
          status: DocStatus.paid,
          number: 'DGF-R-0017',
          date: DateTime(2026, 7, 21),
          clientId: 'c-achieng',
          clientName: 'Mrs. Achieng (home)',
          clientPhone: '+256 758 620 117',
          clientLocation: 'Najjera Ph2',
          vatEnabled: false,
          vatRate: 0.18,
          lines: [
            LineItem(id: 'l9', description: 'Home Wi-Fi setup & extender', quantity: 1, unitPrice: 120000),
          ],
        ),
      ];
}
