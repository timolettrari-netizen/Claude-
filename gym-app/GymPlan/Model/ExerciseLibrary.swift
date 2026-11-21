import Foundation

/// Alle Übungen. Innerhalb eines Bewegungsmusters gilt: weiter oben = wird bevorzugt eingeplant.
enum ExerciseLibrary {
    static let all: [Exercise] = [squat, hinge, lunge, push, pull, arms, legsIso, core].flatMap { $0 }

    static let byID: [String: Exercise] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func exercise(_ id: String) -> Exercise? { byID[id] }
    static func name(_ id: String) -> String { byID[id]?.name ?? id }

    private static func ex(_ id: String, _ name: String, _ pattern: MovementPattern, _ gear: Gear,
                           lvl: Int = 0, comp: Bool = false, avoid: Set<Limitation> = [],
                           timed: Bool = false, cues: [String]) -> Exercise {
        Exercise(id: id, name: name, pattern: pattern, gear: gear, level: lvl, compound: comp,
                 avoid: avoid, timed: timed, cues: cues)
    }

    // MARK: Beine – Kniebeuge, Hüftstreckung, einbeinig

    private static let squat: [Exercise] = [
        ex("back_squat", "Kniebeuge (Langhantel)", .squat, .barbell, lvl: 1, comp: true, avoid: [.knee, .lowerBack],
           cues: ["Stange auf dem oberen Rücken, Füße schulterbreit", "Brust raus, Knie in Richtung Zehen schieben", "Mindestens bis Oberschenkel parallel, aus der Ferse hochdrücken"]),
        ex("leg_press", "Beinpresse", .squat, .machine, comp: true,
           cues: ["Füße hüftbreit mittig auf die Platte", "Unteren Rücken an der Lehne lassen", "Knie nicht ganz durchstrecken"]),
        ex("hack_squat", "Hackenschmidt-Kniebeuge", .squat, .machine, lvl: 1, comp: true, avoid: [.knee],
           cues: ["Rücken flach an das Polster", "Kontrolliert tief gehen", "Über die ganze Fußsohle drücken"]),
        ex("goblet_squat", "Goblet Squat", .squat, .dumbbell, comp: true, avoid: [.knee],
           cues: ["Kurzhantel senkrecht vor der Brust halten", "Ellbogen zwischen die Knie sinken lassen", "Oberkörper aufrecht"]),
        ex("front_squat", "Frontkniebeuge", .squat, .barbell, lvl: 2, comp: true, avoid: [.knee, .lowerBack],
           cues: ["Stange vorne auf den Schultern, Ellbogen hoch", "Oberkörper sehr aufrecht", "Tief und kontrolliert"]),
        ex("bw_squat", "Kniebeuge (Körpergewicht)", .squat, .bodyweight, comp: true, avoid: [.knee],
           cues: ["Arme nach vorne, Gewicht auf den Fersen", "Hüfte nach hinten unten", "Langsam runter, zügig hoch"]),
        ex("box_squat", "Box-Kniebeuge", .squat, .bodyweight, comp: true,
           cues: ["Vor eine Bank oder einen Stuhl stellen", "Kurz absitzen, nicht fallen lassen", "Aus den Fersen aufstehen"]),
    ]

    private static let hinge: [Exercise] = [
        ex("rdl", "Rumänisches Kreuzheben (Langhantel)", .hinge, .barbell, lvl: 1, comp: true, avoid: [.lowerBack],
           cues: ["Knie leicht gebeugt, Hüfte nach hinten schieben", "Stange nah an den Beinen führen", "Rücken gerade, Dehnung hinten im Oberschenkel spüren"]),
        ex("deadlift", "Kreuzheben", .hinge, .barbell, lvl: 1, comp: true, avoid: [.lowerBack],
           cues: ["Stange über der Fußmitte, schulterbreiter Griff", "Rücken anspannen, Brust raus", "Mit den Beinen vom Boden drücken, Hüfte zum Schluss strecken"]),
        ex("db_rdl", "Rumänisches Kreuzheben (Kurzhantel)", .hinge, .dumbbell, comp: true, avoid: [.lowerBack],
           cues: ["Hanteln vor den Oberschenkeln", "Hüfte weit nach hinten, Rücken gerade", "Bis kurz unter die Knie absenken"]),
        ex("back_extension", "Hyperextensions (Rückenstrecker)", .hinge, .machine, comp: true,
           cues: ["Hüfte auf das Polster legen", "Aus der Hüfte beugen, nicht aus dem Rücken", "Oben nicht ins Hohlkreuz gehen"]),
        ex("pull_through", "Pull-Through am Kabel", .hinge, .cable, comp: true,
           cues: ["Mit dem Rücken zum Kabelzug, Seil zwischen den Beinen", "Hüfte nach hinten schieben", "Po fest anspannen und nach vorne strecken"]),
        ex("sl_rdl_bw", "Einbeiniges Kreuzheben", .hinge, .bodyweight, comp: true,
           cues: ["Auf einem Bein stehen, Knie leicht gebeugt", "Oberkörper und freies Bein bilden eine Linie", "Langsam und mit Balance"]),
    ]

    private static let lunge: [Exercise] = [
        ex("bulgarian", "Bulgarische Split-Kniebeuge", .lunge, .dumbbell, lvl: 1, comp: true, avoid: [.knee],
           cues: ["Hinterer Fuß auf der Bank", "Senkrecht nach unten sinken", "Vorderes Knie stabil über dem Fuß"]),
        ex("db_lunge", "Ausfallschritte (Kurzhanteln)", .lunge, .dumbbell, comp: true, avoid: [.knee],
           cues: ["Großer Schritt nach vorne", "Hinteres Knie fast bis zum Boden", "Über die vordere Ferse zurückdrücken"]),
        ex("step_up", "Step-ups auf Bank", .lunge, .dumbbell, comp: true,
           cues: ["Ganzen Fuß auf die Bank setzen", "Nur mit dem oberen Bein hochdrücken", "Langsam wieder absenken"]),
        ex("bw_lunge", "Ausfallschritte (Körpergewicht)", .lunge, .bodyweight, comp: true, avoid: [.knee],
           cues: ["Hände an die Hüfte", "Oberkörper aufrecht", "Beine abwechseln"]),
        ex("bw_step_up", "Step-ups (Körpergewicht)", .lunge, .bodyweight, comp: true,
           cues: ["Stabile Stufe oder Bank nutzen", "Oben ganz aufrichten", "Kontrolliert runter"]),
    ]

    // MARK: Oberkörper – Drücken und Ziehen

    private static let push: [Exercise] = [
        ex("bench", "Bankdrücken (Langhantel)", .horizontalPush, .barbell, lvl: 1, comp: true,
           cues: ["Schulterblätter zusammen und nach unten", "Stange zur unteren Brust senken", "Füße fest am Boden, explosiv drücken"]),
        ex("incline_db", "Schrägbankdrücken (Kurzhantel)", .horizontalPush, .dumbbell, comp: true,
           cues: ["Bank auf 30–45 Grad", "Hanteln bis auf Brusthöhe senken", "Oben nicht zusammenschlagen"]),
        ex("db_bench", "Kurzhantel-Bankdrücken", .horizontalPush, .dumbbell, comp: true,
           cues: ["Ellbogen etwa 45 Grad vom Körper", "Tief absenken, Dehnung in der Brust", "Gleichmäßig nach oben drücken"]),
        ex("chest_press", "Brustpresse (Maschine)", .horizontalPush, .machine, comp: true,
           cues: ["Griffe auf Brusthöhe einstellen", "Schultern hinten lassen", "Langsam zurückführen"]),
        ex("incline_bench", "Schrägbankdrücken (Langhantel)", .horizontalPush, .barbell, lvl: 1, comp: true,
           cues: ["Bank auf etwa 30 Grad", "Stange zur oberen Brust", "Schulterblätter fest"]),
        ex("pushup", "Liegestütze", .horizontalPush, .bodyweight, comp: true,
           cues: ["Körper bildet eine gerade Linie", "Brust bis knapp über den Boden", "Zu schwer? Hände auf eine Bank"]),

        ex("ohp", "Schulterdrücken stehend (Langhantel)", .verticalPush, .barbell, lvl: 1, comp: true, avoid: [.shoulder, .lowerBack],
           cues: ["Bauch und Po fest anspannen", "Stange gerade über den Kopf drücken", "Kopf kurz nach hinten, dann durch"]),
        ex("db_shoulder", "Kurzhantel-Schulterdrücken sitzend", .verticalPush, .dumbbell, comp: true, avoid: [.shoulder],
           cues: ["Lehne fast senkrecht", "Hanteln auf Ohrhöhe starten", "Nach oben drücken, ohne Hohlkreuz"]),
        ex("machine_shoulder", "Schulterpresse (Maschine)", .verticalPush, .machine, comp: true, avoid: [.shoulder],
           cues: ["Sitz so einstellen, dass die Griffe auf Schulterhöhe sind", "Rücken an die Lehne", "Kontrolliert ablassen"]),
        ex("landmine_press", "Landmine Press", .verticalPush, .barbell, lvl: 1, comp: true,
           cues: ["Stangenende in der Ecke oder Halterung", "Schräg nach vorne oben drücken", "Schonend für die Schulter"]),
        ex("pike_pushup", "Pike-Liegestütze", .verticalPush, .bodyweight, lvl: 1, comp: true, avoid: [.shoulder],
           cues: ["Hüfte hoch, Körper als umgedrehtes V", "Kopf Richtung Boden zwischen die Hände", "Zurück nach oben drücken"]),

        ex("cable_fly", "Cable Flys (Kabelzug)", .chestIso, .cable,
           cues: ["Leicht gebeugte Ellbogen", "In einem Bogen vor der Brust zusammenführen", "Langsam öffnen"]),
        ex("pec_deck", "Butterfly (Maschine)", .chestIso, .machine,
           cues: ["Griffe auf Brusthöhe", "Brust raus, Schultern hinten", "Vorne kurz zusammendrücken"]),
        ex("db_fly", "Kurzhantel-Flys", .chestIso, .dumbbell, avoid: [.shoulder],
           cues: ["Arme leicht gebeugt", "Nur bis auf Schulterhöhe öffnen", "Wie eine Umarmung zusammenführen"]),

        ex("lateral_raise", "Seitheben (Kurzhantel)", .shoulderIso, .dumbbell,
           cues: ["Leicht nach vorne geneigt", "Arme bis Schulterhöhe heben", "Ohne Schwung, langsam ablassen"]),
        ex("cable_lateral", "Seitheben am Kabel", .shoulderIso, .cable,
           cues: ["Kabel von unten, einarmig", "Seitlich bis Schulterhöhe", "Spannung auch unten halten"]),
        ex("ytw", "Y-T-W-Heben (Bauchlage)", .shoulderIso, .bodyweight,
           cues: ["Bauchlage, Stirn leicht angehoben", "Arme nacheinander als Y, T und W heben", "Schulterblätter zusammen"]),

        ex("face_pull", "Face Pulls", .rearDelt, .cable,
           cues: ["Seil auf Gesichtshöhe", "Zur Stirn ziehen, Ellbogen hoch", "Hände am Ende nach außen drehen"]),
        ex("reverse_pec_deck", "Reverse Butterfly", .rearDelt, .machine,
           cues: ["Brust an das Polster", "Arme leicht gebeugt nach hinten führen", "Schulterblätter zusammen"]),
        ex("db_reverse_fly", "Vorgebeugtes Seitheben", .rearDelt, .dumbbell,
           cues: ["Oberkörper fast waagerecht", "Arme seitlich nach außen heben", "Kleine Gewichte, saubere Technik"]),
        ex("snow_angel", "Reverse Snow Angels", .rearDelt, .bodyweight,
           cues: ["Bauchlage, Arme an der Seite", "Arme im Bogen über den Kopf führen", "Brust leicht vom Boden"]),
    ]

    private static let pull: [Exercise] = [
        ex("barbell_row", "Langhantelrudern vorgebeugt", .horizontalPull, .barbell, lvl: 1, comp: true, avoid: [.lowerBack],
           cues: ["Oberkörper etwa 45 Grad nach vorne", "Stange zum Bauchnabel ziehen", "Rücken gerade halten"]),
        ex("cable_row", "Rudern am Kabel sitzend", .horizontalPull, .cable, comp: true,
           cues: ["Aufrecht sitzen, Brust raus", "Griff zum Bauch ziehen", "Schulterblätter am Ende zusammen"]),
        ex("db_row", "Einarmiges Kurzhantelrudern", .horizontalPull, .dumbbell, comp: true,
           cues: ["Knie und Hand auf der Bank", "Hantel zur Hüfte ziehen", "Rücken parallel zum Boden"]),
        ex("chest_row", "Brustgestütztes Rudern (Maschine)", .horizontalPull, .machine, comp: true,
           cues: ["Brust an das Polster", "Ellbogen nah am Körper nach hinten", "Kurz halten, langsam zurück"]),
        ex("inverted_row", "Australian Pull-ups", .horizontalPull, .bodyweight, comp: true,
           cues: ["Unter einen stabilen Tisch oder eine tiefe Stange", "Körper gerade, Brust zur Kante ziehen", "Je flacher, desto schwerer"]),

        ex("pullup", "Klimmzüge", .verticalPull, .bar, lvl: 1, comp: true,
           cues: ["Schulterbreiter Obergriff", "Brust zur Stange ziehen", "Ganz nach unten ablassen"]),
        ex("lat_pulldown", "Latzug breit", .verticalPull, .cable, comp: true,
           cues: ["Oberschenkel unter die Polster", "Stange zur oberen Brust ziehen", "Ellbogen nach unten zur Hüfte"]),
        ex("close_pulldown", "Latzug eng (Untergriff)", .verticalPull, .cable, comp: true,
           cues: ["Schulterbreiter Untergriff", "Zur Brust ziehen", "Oben die Arme ganz strecken"]),
        ex("assisted_pullup", "Klimmzüge mit Band", .verticalPull, .bar, comp: true,
           cues: ["Band um die Stange und unter Knie oder Fuß", "Brust zur Stange", "Dünneres Band = mehr Fortschritt"]),
        ex("db_pullover", "Kurzhantel-Überzüge", .verticalPull, .dumbbell,
           cues: ["Quer auf der Bank, Hantel über der Brust", "Mit leicht gebeugten Armen hinter den Kopf", "Mit dem Rücken zurückziehen"]),
    ]

    // MARK: Arme

    private static let arms: [Exercise] = [
        ex("db_curl", "Kurzhantel-Curls", .biceps, .dumbbell,
           cues: ["Ellbogen am Körper", "Handflächen nach oben drehen", "Langsam ablassen"]),
        ex("barbell_curl", "Langhantel-Curls", .biceps, .barbell,
           cues: ["Schulterbreiter Griff", "Ohne Schwung aus dem Rücken", "Oben kurz anspannen"]),
        ex("hammer_curl", "Hammer-Curls", .biceps, .dumbbell,
           cues: ["Daumen zeigen nach oben", "Ellbogen bleiben ruhig", "Abwechselnd oder gleichzeitig"]),
        ex("cable_curl", "Kabel-Curls", .biceps, .cable,
           cues: ["Kabel von unten", "Konstante Spannung", "Oberarme senkrecht"]),
        ex("incline_curl", "Schrägbank-Curls", .biceps, .dumbbell, lvl: 1,
           cues: ["Bank auf 45–60 Grad", "Arme hängen hinter dem Körper", "Volle Dehnung unten"]),
        ex("chinup", "Klimmzüge im Untergriff", .biceps, .bar, lvl: 1, comp: true,
           cues: ["Schulterbreiter Untergriff", "Kinn über die Stange", "Kontrolliert ablassen"]),

        ex("pushdown", "Trizepsdrücken am Kabel", .triceps, .cable,
           cues: ["Ellbogen fest am Körper", "Nach unten ganz strecken", "Nur die Unterarme bewegen"]),
        ex("overhead_ext", "Überkopf-Trizepsstrecken (Kabel)", .triceps, .cable, avoid: [.shoulder],
           cues: ["Mit dem Rücken zum Kabel", "Seil über den Kopf nach vorne strecken", "Ellbogen zeigen nach vorne"]),
        ex("skullcrusher", "French Press (SZ-Stange)", .triceps, .barbell, lvl: 1,
           cues: ["Auf der Bank liegend", "Stange zur Stirn senken", "Oberarme bleiben still"]),
        ex("dips", "Dips (Barren)", .triceps, .bar, lvl: 1, comp: true, avoid: [.shoulder],
           cues: ["Oberkörper aufrecht für Trizeps", "Bis Oberarme etwa parallel", "Oben ganz strecken"]),
        ex("db_overhead", "Überkopf-Trizepsstrecken (Kurzhantel)", .triceps, .dumbbell, avoid: [.shoulder],
           cues: ["Hantel mit beiden Händen hinter den Kopf", "Ellbogen eng", "Nach oben strecken"]),
        ex("kickback", "Trizeps-Kickbacks", .triceps, .dumbbell,
           cues: ["Oberkörper vorgebeugt, Oberarm am Körper", "Unterarm nach hinten strecken", "Kurz halten"]),
        ex("diamond_pushup", "Enge Liegestütze", .triceps, .bodyweight,
           cues: ["Hände eng unter der Brust", "Ellbogen nah am Körper", "Zu schwer? Auf den Knien"]),
        ex("bench_dip", "Bank-Dips", .triceps, .bodyweight, avoid: [.shoulder],
           cues: ["Hände hinter dir auf der Bank", "Bis Oberarme parallel absenken", "Hüfte nah an der Bank"]),
    ]

    // MARK: Beine – Isolation

    private static let legsIso: [Exercise] = [
        ex("leg_ext", "Beinstrecker", .quadIso, .machine, avoid: [.knee],
           cues: ["Knie auf Höhe des Drehpunkts", "Oben kurz halten", "Langsam ablassen"]),
        ex("wall_sit", "Wandsitzen", .quadIso, .bodyweight, timed: true,
           cues: ["Rücken an der Wand", "Knie etwa 90 Grad", "Gleichmäßig atmen"]),

        ex("lying_leg_curl", "Beinbeuger liegend", .hamIso, .machine,
           cues: ["Polster knapp über der Ferse", "Hüfte bleibt auf der Bank", "Langsam zurück"]),
        ex("seated_leg_curl", "Beinbeuger sitzend", .hamIso, .machine,
           cues: ["Oberschenkel fest fixieren", "Ferse nach unten hinten ziehen", "Volle Bewegung"]),
        ex("slider_curl", "Leg Curls mit Handtuch", .hamIso, .bodyweight,
           cues: ["Rückenlage, Fersen auf einem Handtuch", "Hüfte hoch, Fersen zum Po ziehen", "Langsam wieder strecken"]),
        ex("nordic", "Nordic Hamstring Curls", .hamIso, .bodyweight, lvl: 2,
           cues: ["Fersen fixieren lassen", "Langsam nach vorne fallen lassen", "Mit den Händen abfangen"]),

        ex("hip_thrust", "Hip Thrust (Langhantel)", .glute, .barbell, comp: true,
           cues: ["Schultern auf der Bank, Stange auf der Hüfte (mit Polster)", "Hüfte nach oben strecken", "Oben Po fest anspannen"]),
        ex("cable_kickback", "Kabel-Kickbacks", .glute, .cable,
           cues: ["Manschette am Fuß", "Bein gestreckt nach hinten führen", "Kein Hohlkreuz"]),
        ex("abductor", "Abduktoren-Maschine", .glute, .machine,
           cues: ["Oberkörper leicht nach vorne", "Beine nach außen drücken", "Langsam zurück"]),
        ex("db_hip_thrust", "Hip Thrust (Kurzhantel)", .glute, .dumbbell, comp: true,
           cues: ["Hantel auf die Hüfte legen", "Kinn zur Brust", "Oben 1 Sekunde halten"]),
        ex("glute_bridge", "Glute Bridge", .glute, .bodyweight,
           cues: ["Rückenlage, Füße nah am Po", "Hüfte hoch bis zur Linie", "Einbeinig ist schwerer"]),

        ex("standing_calf", "Wadenheben stehend (Maschine)", .calves, .machine,
           cues: ["Fußballen auf der Kante", "Ganz nach oben, ganz nach unten", "Unten kurz dehnen"]),
        ex("seated_calf", "Wadenheben sitzend", .calves, .machine,
           cues: ["Polster auf den Knien", "Langsam und vollständig", "Oben halten"]),
        ex("db_calf", "Wadenheben mit Kurzhanteln", .calves, .dumbbell,
           cues: ["Auf einer Stufe stehen", "Hanteln seitlich halten", "Volle Bewegung"]),
        ex("bw_calf", "Einbeiniges Wadenheben", .calves, .bodyweight,
           cues: ["Auf einer Stufe, eine Hand an der Wand", "Langsam hoch und runter", "Beide Seiten"]),
    ]

    // MARK: Rumpf

    private static let core: [Exercise] = [
        ex("cable_crunch", "Kabel-Crunches", .core, .cable,
           cues: ["Kniend vor dem Kabelzug, Seil am Kopf", "Rücken nach unten einrollen", "Hüfte bleibt still"]),
        ex("hanging_leg_raise", "Beinheben hängend", .core, .bar, lvl: 1,
           cues: ["An der Stange hängen", "Knie oder Beine ohne Schwung hochziehen", "Becken nach oben kippen"]),
        ex("plank", "Unterarmstütz (Plank)", .core, .bodyweight, timed: true,
           cues: ["Ellbogen unter den Schultern", "Po und Bauch anspannen", "Körper in einer Linie"]),
        ex("pallof", "Pallof Press", .core, .cable,
           cues: ["Seitlich zum Kabel stehen", "Griff vor der Brust nach vorne drücken", "Nicht verdrehen lassen"]),
        ex("dead_bug", "Dead Bug", .core, .bodyweight,
           cues: ["Rückenlage, Arme und Beine nach oben", "Gegengleich Arm und Bein strecken", "Unterer Rücken bleibt am Boden"]),
        ex("side_plank", "Seitstütz", .core, .bodyweight, timed: true,
           cues: ["Ellbogen unter der Schulter", "Hüfte hoch halten", "Beide Seiten"]),
        ex("ab_wheel", "Ab Wheel Rollout", .core, .bodyweight, lvl: 2, avoid: [.lowerBack],
           cues: ["Kniend starten", "Langsam nach vorne rollen", "Kein Durchhängen im Rücken"]),
    ]
}
