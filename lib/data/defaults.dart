import '../models/board.dart';
import '../models/workspace.dart';

/// Seed data shown on first launch and after `Reset data`. Pure data — no
/// Flutter / build-context dependencies — so it tests cleanly and doesn't
/// bloat `home_screen.dart`. Used from `HomeScreen._load` and from the
/// About dialog's reset flow (via BoardsController).
({List<Workspace> workspaces, List<Board> boards}) buildDefaults() {
  final welcome = Workspace(name: 'Welcome', colorIndex: 4);
  final cooking = Workspace(name: 'Cooking Recipes', colorIndex: 0);
  final workout = Workspace(name: 'Workout Routines', colorIndex: 3);
  final french = Workspace(name: 'French Vocab', colorIndex: 5);
  final pilot = Workspace(name: 'Pilot Checklists', colorIndex: 7);

  final workspaces = [welcome, cooking, workout, french, pilot];
  final boards = <Board>[
    // --- Welcome ---
    Board(name: 'Getting Started', type: BoardType.thoughts, workspaceId: welcome.id, items: [
      BoardItem(content: 'Welcome', description: 'A place for your thoughts, tasks, and memories. Tap a marble to peek inside.', colorIndex: 0, sizeMultiplier: 1.5),
      BoardItem(content: 'Fling me!', description: 'Drag marbles around and let them go — they bounce off the walls.', colorIndex: 1),
      BoardItem(content: 'Long-press', description: 'Hold down on any marble to edit or delete it.', colorIndex: 2, sizeMultiplier: 0.8),
      BoardItem(content: 'Workspaces', description: 'Boards are grouped into workspaces. Collapse a workspace by tapping its header. Use the folder icon to create new ones.', colorIndex: 3, sizeMultiplier: 0.6),
      BoardItem(content: 'Penser', description: 'French for "to think". That\'s what this app is for.', colorIndex: 4, sizeMultiplier: 1.2),
    ]),
    Board(name: 'Weekend', type: BoardType.todo, workspaceId: welcome.id, items: [
      BoardItem(content: 'Water the plants', colorIndex: 5),
      BoardItem(content: 'Call grandma', colorIndex: 6),
      BoardItem(content: 'Finish that book', colorIndex: 7),
      BoardItem(content: 'Try a new recipe', colorIndex: 0),
    ]),

    // --- Cooking Recipes ---
    Board(name: 'Pancakes', type: BoardType.checklist, workspaceId: cooking.id, items: [
      BoardItem(content: 'Mix dry ingredients', description: '1 cup flour, 2 tbsp sugar, pinch of salt.', colorIndex: 0),
      BoardItem(content: 'Add wet ingredients', description: '1 egg, 3/4 cup milk, 2 tbsp melted butter.', colorIndex: 1),
      BoardItem(content: 'Whisk until smooth', description: 'A few lumps are fine — don\'t overmix!', colorIndex: 2),
      BoardItem(content: 'Heat the pan', description: 'Medium heat, small knob of butter. Wait until it sizzles.', colorIndex: 3),
      BoardItem(content: 'Cook pancakes', description: 'Pour 1/4 cup batter. Flip when bubbles pop on the surface.', colorIndex: 4),
      BoardItem(content: 'Serve', description: 'Stack them up. Maple syrup, berries, whatever you like.', colorIndex: 5),
    ]),
    Board(name: 'Pasta Aglio e Olio', type: BoardType.checklist, workspaceId: cooking.id, items: [
      BoardItem(content: 'Boil pasta', description: 'Salt the water generously. Cook spaghetti until al dente.', colorIndex: 1),
      BoardItem(content: 'Slice garlic', description: '6 cloves, thinly sliced. The thinner, the crispier.', colorIndex: 2),
      BoardItem(content: 'Toast garlic in oil', description: 'Low heat, olive oil, until just golden. Don\'t burn it!', colorIndex: 3),
      BoardItem(content: 'Add chili flakes', description: 'A good pinch of red pepper flakes. Off the heat to avoid burning.', colorIndex: 0),
      BoardItem(content: 'Toss with pasta', description: 'Add pasta + a splash of pasta water. Toss until glossy.', colorIndex: 4),
      BoardItem(content: 'Finish', description: 'Fresh parsley, more olive oil, and parmesan if you like.', colorIndex: 5),
    ]),
    Board(name: 'Grocery List', type: BoardType.todo, workspaceId: cooking.id, items: [
      BoardItem(content: 'Eggs', colorIndex: 1),
      BoardItem(content: 'Flour', colorIndex: 2),
      BoardItem(content: 'Olive oil', colorIndex: 3),
      BoardItem(content: 'Garlic', colorIndex: 0),
      BoardItem(content: 'Parsley', colorIndex: 4),
    ]),

    // --- Workout Routines ---
    Board(name: 'Morning Stretch', type: BoardType.checklist, workspaceId: workout.id, items: [
      BoardItem(content: 'Neck rolls', description: '30 seconds each direction. Slow and gentle.', colorIndex: 3),
      BoardItem(content: 'Shoulder shrugs', description: '10 reps. Squeeze at the top.', colorIndex: 4),
      BoardItem(content: 'Cat-cow stretch', description: '8 reps. Sync with your breath.', colorIndex: 5),
      BoardItem(content: 'Forward fold', description: 'Hold for 30 seconds. Let gravity do the work.', colorIndex: 6),
      BoardItem(content: 'Hip circles', description: '10 each direction. Loosen up those hips.', colorIndex: 7),
    ]),
    Board(name: 'Push Day', type: BoardType.todo, workspaceId: workout.id, items: [
      BoardItem(content: 'Bench press 4x8', colorIndex: 0),
      BoardItem(content: 'Overhead press 3x10', colorIndex: 1),
      BoardItem(content: 'Incline dumbbell press 3x12', colorIndex: 2),
      BoardItem(content: 'Lateral raises 3x15', colorIndex: 3),
      BoardItem(content: 'Tricep dips 3x12', colorIndex: 4),
    ]),
    Board(name: 'Running Log', type: BoardType.thoughts, workspaceId: workout.id, items: [
      BoardItem(content: 'Mon 5K', description: '27:12 — felt good, new route through the park.', colorIndex: 3),
      BoardItem(content: 'Wed 3K', description: '16:45 — easy recovery run. Legs still sore from push day.', colorIndex: 4),
      BoardItem(content: 'Sat 8K', description: '42:30 — long run PB! Negative split in the last 2K.', colorIndex: 5),
    ]),

    // --- French Vocab ---
    Board(name: 'Essentials', type: BoardType.flashcards, workspaceId: french.id, items: [
      BoardItem(content: 'Penser', backContent: 'To think', colorIndex: 0),
      BoardItem(content: 'Souvenir', backContent: 'Memory', colorIndex: 1),
      BoardItem(content: 'Oublier', backContent: 'To forget', colorIndex: 2),
      BoardItem(content: 'Comprendre', backContent: 'To understand', colorIndex: 3),
      BoardItem(content: 'Savoir', backContent: 'To know (a fact)', colorIndex: 4),
      BoardItem(content: 'Pouvoir', backContent: 'To be able to / can', colorIndex: 5),
    ]),
    Board(name: 'Nature', type: BoardType.flashcards, workspaceId: french.id, items: [
      BoardItem(content: 'Nuage', backContent: 'Cloud', colorIndex: 7),
      BoardItem(content: 'Lune', backContent: 'Moon', colorIndex: 5),
      BoardItem(content: 'Fleuve', backContent: 'River (large)', colorIndex: 4),
      BoardItem(content: 'Feuille', backContent: 'Leaf', colorIndex: 3),
    ]),
    Board(name: 'Faux Amis', type: BoardType.flashcards, workspaceId: french.id, items: [
      BoardItem(content: 'Actuellement', backContent: 'Currently', description: 'Means "currently/right now" — NOT "actually". For "actually" use "en fait".', colorIndex: 0),
      BoardItem(content: 'Bras', backContent: 'Arm', description: 'The body part. A "bra" (undergarment) is "soutien-gorge".', colorIndex: 1),
      BoardItem(content: 'Chair', backContent: 'Flesh', description: 'As in the human body. A chair (furniture) is "chaise".', colorIndex: 2),
      BoardItem(content: 'Monnaie', backContent: 'Change / coins', description: 'Small change in your pocket. Money in general is "argent".', colorIndex: 6),
      BoardItem(content: 'Raisin', backContent: 'Grape', description: 'The fresh fruit. A dried raisin is "raisin sec".', colorIndex: 7),
    ]),

    // --- Pilot Checklists ---
    Board(name: 'Pre-Flight', type: BoardType.checklist, workspaceId: pilot.id, items: [
      BoardItem(content: 'Weather briefing', description: 'Check METAR, TAF, NOTAMs for departure, en-route, and destination.', colorIndex: 7),
      BoardItem(content: 'Weight & balance', description: 'Calculate total weight, CG position. Verify within limits.', colorIndex: 4),
      BoardItem(content: 'Fuel check', description: 'Visual inspection of fuel level. Confirm sufficient for flight + reserves.', colorIndex: 3),
      BoardItem(content: 'Walk-around', description: 'Inspect control surfaces, tires, pitot tube, oil level, antennas.', colorIndex: 0),
      BoardItem(content: 'Instruments check', description: 'Altimeter set, heading indicator aligned, radios tuned.', colorIndex: 1),
    ]),
    Board(name: 'Before Takeoff', type: BoardType.checklist, workspaceId: pilot.id, items: [
      BoardItem(content: 'Seats & belts', description: 'Seats locked, belts fastened, shoulder harness secured.', colorIndex: 7),
      BoardItem(content: 'Flight controls', description: 'Free and correct. Full deflection all axes.', colorIndex: 0),
      BoardItem(content: 'Fuel selector', description: 'Set to BOTH (or fullest tank as appropriate).', colorIndex: 3),
      BoardItem(content: 'Trim', description: 'Set for takeoff.', colorIndex: 4),
      BoardItem(content: 'Transponder', description: 'Set to ALT. Squawk assigned code.', colorIndex: 1),
      BoardItem(content: 'Lights', description: 'Landing light ON, strobes ON, nav lights ON.', colorIndex: 5),
    ]),
    Board(name: 'Emergency: Engine Failure', type: BoardType.checklist, workspaceId: pilot.id, items: [
      BoardItem(content: 'Airspeed', description: 'Best glide speed immediately. Pitch for Vg.', colorIndex: 0),
      BoardItem(content: 'Best field', description: 'Pick a landing spot. Fly toward it. Commit early.', colorIndex: 1),
      BoardItem(content: 'Restart attempt', description: 'Fuel selector BOTH, mixture RICH, carb heat ON, mags BOTH, primer IN & LOCKED.', colorIndex: 2),
      BoardItem(content: 'Mayday call', description: '121.5 MHz — "Mayday, Mayday, Mayday" + callsign, position, intentions.', colorIndex: 0),
      BoardItem(content: 'Secure engine', description: 'If no restart: mixture CUTOFF, fuel selector OFF, mags OFF, master OFF (flaps last).', colorIndex: 7),
    ]),
    Board(name: 'Flight Log', type: BoardType.timer, workspaceId: pilot.id, items: [
      BoardItem(content: 'Engine start', description: 'Pre-start checks complete. Engine running, radios tuned, ready to taxi. Tap to start the clock.', colorIndex: 3),
      BoardItem(content: 'Taxi', description: 'Ground movement to runway holding point.', colorIndex: 4),
      BoardItem(content: 'Takeoff & Climb', description: 'Departure and climb to cruise altitude.', colorIndex: 2),
      BoardItem(content: 'Cruise', description: 'En-route level flight.', colorIndex: 1),
      BoardItem(content: 'Descent & Approach', description: 'Arrival procedures and approach.', colorIndex: 5),
      BoardItem(content: 'Landing', description: 'Touchdown and roll-out to taxi speed.', colorIndex: 7),
      BoardItem(content: 'Shutdown', description: 'Taxi to parking, mixture CUTOFF, mags OFF, master OFF. Tap to stop the clock.', colorIndex: 0),
    ]),

    // --- Workout countdown ---
    Board(name: 'Tabata', type: BoardType.countdown, workspaceId: workout.id, items: [
      BoardItem(content: 'Warm-up', description: 'Easy movement — light cardio, joint mobility.', durationSeconds: 60, colorIndex: 3),
      BoardItem(content: 'Jumping Jacks', durationSeconds: 20, colorIndex: 0),
      BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
      BoardItem(content: 'Squats', durationSeconds: 20, colorIndex: 1),
      BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
      BoardItem(content: 'Push-ups', durationSeconds: 20, colorIndex: 3),
      BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
      BoardItem(content: 'Burpees', durationSeconds: 20, colorIndex: 5),
      BoardItem(content: 'Rest', durationSeconds: 10, colorIndex: 7),
      BoardItem(content: 'Cool-down', description: 'Stretch, lower heart rate, hydrate.', durationSeconds: 60, colorIndex: 4),
    ]),
  ];

  return (workspaces: workspaces, boards: boards);
}
