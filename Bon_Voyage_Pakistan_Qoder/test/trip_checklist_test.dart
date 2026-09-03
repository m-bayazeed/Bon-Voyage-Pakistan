import 'package:flutter_test/flutter_test.dart';
import 'package:bon_voyage_pakistan/models/trip_checklist_item_model.dart';
import 'package:bon_voyage_pakistan/models/trip_plan_model.dart';

void main() {
  group('TripChecklistItem Model & Origin Tags Tests', () {
    test('Smart Origin Tags and Icons match requirements', () {
      expect(ChecklistCategory.hotel.originTag, equals('[🏨 Hotel]'));
      expect(ChecklistCategory.food.originTag, equals('[🍲 Food]'));
      expect(ChecklistCategory.plan.originTag, equals('[📌 Plan]'));
      expect(ChecklistCategory.task.originTag, equals('[🏷 Task]'));
    });

    test('TripChecklistItem serialization and deserialization works correctly', () {
      final now = DateTime.now();
      final item = TripChecklistItem(
        id: 'CHK-TEST-001',
        planId: 'PLAN-HUNZA-001',
        title: 'Visit Baltit Fort',
        category: ChecklistCategory.plan,
        referenceId: 'REF-001',
        dayNumber: 2,
        dayTitle: 'Day 2: Naran to Hunza',
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = item.toMap();
      expect(map['id'], equals('CHK-TEST-001'));
      expect(map['plan_id'], equals('PLAN-HUNZA-001'));
      expect(map['title'], equals('Visit Baltit Fort'));
      expect(map['category'], equals('plan'));
      expect(map['day_number'], equals(2));
      expect(map['is_completed'], equals(0));

      final deserialized = TripChecklistItem.fromMap(map);
      expect(deserialized.id, equals(item.id));
      expect(deserialized.planId, equals(item.planId));
      expect(deserialized.title, equals(item.title));
      expect(deserialized.category, equals(ChecklistCategory.plan));
      expect(deserialized.dayNumber, equals(2));
      expect(deserialized.isCompleted, isFalse);
      expect(deserialized.originTag, equals('[📌 Plan]'));
    });

    test('TripChecklistItem copyWith toggles completed status cleanly', () {
      final item = TripChecklistItem(
        id: 'CHK-002',
        planId: 'PLAN-001',
        title: 'Pack warm fleece jacket',
        category: ChecklistCategory.task,
        isCompleted: false,
      );

      final completed = item.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
      expect(completed.title, equals('Pack warm fleece jacket'));
      expect(completed.originTag, equals('[🏷 Task]'));
    });
  });

  group('ChatMessage Checklist Action Integration Tests', () {
    test('ChatMessage supports interactive checklist fields', () {
      final msg = ChatMessage(
        id: 'ai-msg-1',
        text: 'I suggest taking trekking poles for Fairy Meadows.',
        isAi: true,
        checklistActionTitle: 'Trekking poles',
        checklistActionDayNumber: 1,
        isChecklistActionAdded: false,
      );

      expect(msg.checklistActionTitle, equals('Trekking poles'));
      expect(msg.checklistActionDayNumber, equals(1));
      expect(msg.isChecklistActionAdded, isFalse);

      final json = msg.toJson();
      expect(json['checklistActionTitle'], equals('Trekking poles'));
      expect(json['checklistActionDayNumber'], equals(1));
      expect(json['isChecklistActionAdded'], isFalse);

      final deserialized = ChatMessage.fromJson(json);
      expect(deserialized.checklistActionTitle, equals('Trekking poles'));
      expect(deserialized.checklistActionDayNumber, equals(1));

      final updated = msg.copyWith(isChecklistActionAdded: true);
      expect(updated.isChecklistActionAdded, isTrue);
    });
  });

  group('TripPlan Finalization Model Tests', () {
    test('TripPlan retains finalization status', () {
      final plan = TripPlan(
        id: 'PLAN-2026-001',
        userId: 101,
        title: '5-Day Hunza Valley Expedition',
        departingCity: 'Islamabad',
        destinationCity: 'Hunza',
        days: 5,
        travelers: 2,
        budgetTier: 'comfort',
        budgetAmountPkr: 100000,
        interests: const ['Sightseeing', 'Culture', 'Photography'],
        transportation: 'Prado 4x4',
        accommodation: 'Standard Hotels',
        budgetBreakdown: const BudgetBreakdown(
          transportPkr: 25000,
          accommodationPkr: 35000,
          foodPkr: 18000,
          activitiesPkr: 10000,
          contingencyPkr: 12000,
        ),
        daysPlan: const [
          ItineraryDay(
            dayNumber: 1,
            title: 'Islamabad to Naran',
            route: 'Hazara Motorway ➔ Babusar Pass',
            timing: 'Early Departure (6:00 AM)',
            attractions: ['Abbottabad', 'Balakot', 'Kaghan'],
            activities: ['Scenic Drive', 'Riverside Lunch in Balakot'],
            foodRecommendation: 'River trout in Balakot',
            stayRecommendation: 'Pine Park Hotel Kaghan',
          ),
          ItineraryDay(
            dayNumber: 2,
            title: 'Naran to Hunza',
            route: 'KKH via Chilas ➔ Gilgit ➔ Karimabad',
            timing: 'Morning Departure',
            attractions: ['Babusar Top', 'Junction Point', 'Rakaposhi Viewpoint'],
            activities: ['Photo stop at Rakaposhi Viewpoint', 'Explore Karimabad bazaar'],
            foodRecommendation: 'Hunza apricot cake at Cafe de Hunza',
            stayRecommendation: 'Serena Inn Hunza',
          ),
        ],
        isFinalized: false,
      );


      expect(plan.isFinalized, isFalse);

      final finalized = plan.copyWith(isFinalized: true);
      expect(finalized.isFinalized, isTrue);
      expect(finalized.daysPlan.length, equals(2));
      expect(finalized.daysPlan[0].activities.length, equals(2));
      expect(finalized.daysPlan[1].stayRecommendation, equals('Serena Inn Hunza'));
    });
  });
}
