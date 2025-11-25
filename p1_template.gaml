/**
 * Name: Practice 1 Wumpus - Environment + Basic Player + Tests
 * Author: Based on template by Raúl Fraile
 */

model Wumpus_template

global {

    // ---------- PARAMETERS FOR THE ENVIRONMENT ----------

    int grid_width <- 10;     // can be changed from the experiment
    int grid_height <- 10;

    int nb_gold <- 6;          // number of treasures (only used in random maps)
    int nb_pits <- 8;          // number of pits     (only used in random maps)

    bool use_random_map <- true;   // false = use the predefined example map

    // ---------- PLAYER PARAMETERS (SECTION 5) ----------

    bool debug_player <- true;     // set true to print each move to the console

    // ---------- BOOKKEEPING FOR TESTS ----------

    bool tests_executed <- false;
    int  tests_failed   <- 0;

    // ---------- INITIALIZATION ----------

    init {
        do setup_world;
        do setup_player;            // <-- Section 5: create + place player
        do run_unit_tests;          // run tests automatically on each reset
    }

    // ============================================================
    //                 WORLD BUILD / RESET
    // ============================================================

    // Create / reset the whole environment (grid contents & percept flags)
    action setup_world {

        // 1) Reset per-cell attributes in the grid
        ask gworld {
            has_pit     <- false;
            has_wumpus  <- false;
            has_gold    <- false;

            breeze <- false;
            stench <- false;
            glow   <- false;
        }

        // 2) Remove any previous environment objects (useful on reset)
        ask player      { do die; }     // <-- ensure we never accumulate players
        ask goldArea    { do die; }
        ask glitterArea { do die; }
        ask wumpusArea  { do die; }
        ask odorArea    { do die; }
        ask pitArea     { do die; }
        ask breezeArea  { do die; }

        // 3) Build either a random map or a fixed test map
        if use_random_map {
            do setup_random_map;
        } else {
            do setup_predefined_map;
        }
    }

    // ============================================================
    //                 SECTION 5: PLAYER CREATION
    // ============================================================

    action setup_player {

        // Safe start: any cell that is NOT a pit and NOT the wumpus
        list<gworld> safe_cells <- gworld where !(each.has_pit or each.has_wumpus);

        if (length(safe_cells) = 0) {
            write "ERROR: No safe cells available to place the player.";
            return;
        }

        gworld start_cell <- one_of(safe_cells);

        create player number: 1 {
            spawn_cell   <- start_cell;
            current_cell <- start_cell;
            last_cell    <- start_cell;

            location <- start_cell.location;

            steps <- 0;
            alive <- true;
            death_cause <- "none";
        }

        if (debug_player) {
            write "Player created at location " + start_cell.location;
        }
    }

    // ============================================================
    //                 RANDOM MAP
    // ============================================================

    action setup_random_map {

        int needed <- 1 + nb_gold + nb_pits;
        int capacity <- grid_width * grid_height;

        if (needed > capacity) {
            write "ERROR: Not enough cells for 1 Wumpus + nb_gold + nb_pits. Increase grid or reduce numbers.";
            return;
        }

        list<gworld> used <- [];

        // --------- Wumpus ----------
        gworld wcell <- one_of(gworld where !(each in used));
        if (wcell = nil) { write "ERROR: Cannot pick a cell for Wumpus."; return; }
        used <- used + [wcell];

        create wumpusArea number: 1 { location <- wcell.location; }
        do initialize_wumpus_percepts(wcell);

        // --------- Gold ----------
        if (nb_gold > 0) {
            loop i from: 1 to: nb_gold {
                gworld gcell <- one_of(gworld where !(each in used));
                if (gcell = nil) { write "ERROR: Cannot pick a cell for Gold."; return; }
                used <- used + [gcell];

                create goldArea number: 1 { location <- gcell.location; }
                do initialize_gold_percepts(gcell);
            }
        }

        // --------- Pits ----------
        if (nb_pits > 0) {
            loop i from: 1 to: nb_pits {
                gworld pcell <- one_of(gworld where !(each in used));
                if (pcell = nil) { write "ERROR: Cannot pick a cell for Pit."; return; }
                used <- used + [pcell];

                create pitArea number: 1 { location <- pcell.location; }
                do initialize_pit_percepts(pcell);
            }
        }
    }

    // ============================================================
    //                 PREDEFINED TEST MAP (SMALL EXAMPLE)
    // ============================================================

    action setup_predefined_map {

        // Predefined coordinates require at least 5x5
        if (grid_width < 5 or grid_height < 5) {
            write "Predefined map requires grid_width and grid_height >= 5. Increase grid size or use random map.";
            return;
        }

        // 1) Wumpus at (3,3)
        create wumpusArea number: 1 {
            gworld place <- gworld grid_at {3, 3};
            if (place = nil) { write "ERROR: gworld cell [3,3] not found."; do die; }
            location <- place.location;
            ask world { do initialize_wumpus_percepts(place); }
        }

        // 2) Gold at (1,4)
        create goldArea number: 1 {
            gworld place <- gworld grid_at {1, 4};
            if (place = nil) { write "ERROR: gworld cell [1,4] not found."; do die; }
            location <- place.location;
            ask world { do initialize_gold_percepts(place); }
        }

        // 3) Pits at (0,2) and (4,1)
        create pitArea number: 1 {
            gworld place <- gworld grid_at {0, 2};
            if (place = nil) { write "ERROR: gworld cell [0,2] not found."; do die; }
            location <- place.location;
            ask world { do initialize_pit_percepts(place); }
        }

        create pitArea number: 1 {
            gworld place <- gworld grid_at {4, 1};
            if (place = nil) { write "ERROR: gworld cell [4,1] not found."; do die; }
            location <- place.location;
            ask world { do initialize_pit_percepts(place); }
        }
    }

    // ============================================================
    //                 HELPERS: UPDATE CELL CONTENT & PERCEPTS
    // ============================================================

    action initialize_wumpus_percepts (gworld place) {

        ask place { has_wumpus <- true; }

        list<gworld> my_neighbors <- [];
        ask place { my_neighbors <- neighbors; }

        loop c over: my_neighbors {
            ask c { stench <- true; }
            create odorArea { location <- c.location; }
        }
    }

    action initialize_gold_percepts (gworld place) {

        ask place { has_gold <- true; }

        list<gworld> my_neighbors <- [];
        ask place { my_neighbors <- neighbors; }

        loop c over: my_neighbors {
            ask c { glow <- true; }
            create glitterArea { location <- c.location; }
        }
    }

    action initialize_pit_percepts (gworld place) {

        ask place { has_pit <- true; }

        list<gworld> my_neighbors <- [];
        ask place { my_neighbors <- neighbors; }

        loop c over: my_neighbors {
            ask c { breeze <- true; }
            create breezeArea { location <- c.location; }
        }
    }

    // ============================================================
    //                  "UNIT TESTS" (ENVIRONMENT + PLAYER)
    // ============================================================

    action run_unit_tests {

        tests_executed <- true;
        tests_failed   <- 0;

        write "============================";
        write "Running Wumpus unit tests (environment + player)...";

        // ----- Environment tests -----
        do test_single_wumpus;
        do test_at_least_one_gold;
        do test_expected_number_of_pits;
        do test_breeze_consistency;
        do test_stench_consistency;
        do test_glow_consistency;

        // ----- Player tests (Section 5) -----
        do test_single_player;
        do test_player_spawn_safe;
        do test_player_step_is_neighbor;
        do test_player_multiple_steps_are_neighbors;
        do test_player_death_detection;

        if (tests_failed = 0) {
            write "All tests PASSED";
        } else {
            write "Tests FAILED. Number of failed tests: " + tests_failed;
        }

        write "============================";
    }

    // ---------------- ENVIRONMENT TESTS ----------------

    // 1) Exactly one Wumpus
    action test_single_wumpus {
        int n <- length(wumpusArea);
        if (n = 1) {
            write "Test 1 (single Wumpus): OK";
        } else {
            write "Test 1 (single Wumpus): FAILED - expected 1, found " + n;
            tests_failed <- tests_failed + 1;
        }
    }

    // 2) Gold count
    action test_at_least_one_gold {
        int n <- length(goldArea);

        if (use_random_map) {
            if (n = nb_gold) {
                write "Test 2 (gold count matches nb_gold): OK";
            } else {
                write "Test 2 (gold count matches nb_gold): FAILED - expected " + nb_gold + ", found " + n;
                tests_failed <- tests_failed + 1;
            }
        } else {
            if (n > 0) {
                write "Test 2 (at least one gold): OK";
            } else {
                write "Test 2 (at least one gold): FAILED - no gold areas created";
                tests_failed <- tests_failed + 1;
            }
        }
    }

    // 3) In random maps, the number of pits must match nb_pits
    action test_expected_number_of_pits {
        int n <- length(pitArea);
        if (use_random_map and n = nb_pits) {
            write "Test 3 (expected number of pits): OK";
        } else if (use_random_map and n != nb_pits) {
            write "Test 3 (expected number of pits): FAILED - expected " + nb_pits + ", found " + n;
            tests_failed <- tests_failed + 1;
        } else {
            write "Test 3 (expected number of pits): SKIPPED for predefined map";
        }
    }

    // 4) For each cell: breeze == true  <=> at least one neighbour has a pit
    action test_breeze_consistency {
        bool ok <- true;

        ask gworld {
            bool expected_breeze <- length(neighbors where (each.has_pit)) > 0;
            if (breeze != expected_breeze) { ok <- false; }
        }

        if ok {
            write "Test 4 (breeze consistency): OK";
        } else {
            write "Test 4 (breeze consistency): FAILED";
            tests_failed <- tests_failed + 1;
        }
    }

    // 5) For each cell: stench == true <=> at least one neighbour has the Wumpus
    action test_stench_consistency {
        bool ok <- true;

        ask gworld {
            bool expected_stench <- length(neighbors where (each.has_wumpus)) > 0;
            if (stench != expected_stench) { ok <- false; }
        }

        if ok {
            write "Test 5 (stench consistency): OK";
        } else {
            write "Test 5 (stench consistency): FAILED";
            tests_failed <- tests_failed + 1;
        }
    }

    // 6) For each cell: glow == true <=> at least one neighbour has gold
    action test_glow_consistency {
        bool ok <- true;

        ask gworld {
            bool expected_glow <- length(neighbors where (each.has_gold)) > 0;
            if (glow != expected_glow) { ok <- false; }
        }

        if ok {
            write "Test 6 (glow consistency): OK";
        } else {
            write "Test 6 (glow consistency): FAILED";
            tests_failed <- tests_failed + 1;
        }
    }

    // ---------------- PLAYER TESTS (SECTION 5) ----------------

    // 7) Exactly one player
    action test_single_player {
        int n <- length(player);
        if (n = 1) {
            write "Test 7 (single player): OK";
        } else {
            write "Test 7 (single player): FAILED - expected 1, found " + n;
            tests_failed <- tests_failed + 1;
        }
    }

    // 8) Player does not spawn on pit or wumpus
    action test_player_spawn_safe {
        if (length(player) != 1) {
            write "Test 8 (player spawn safe): FAILED - no unique player to test";
            tests_failed <- tests_failed + 1;
            return;
        }

        player p <- one_of(player);
        bool ok <- true;

        if (p.current_cell = nil) { ok <- false; }
        else if (p.current_cell.has_pit or p.current_cell.has_wumpus) { ok <- false; }
        else if (p.location != p.current_cell.location) { ok <- false; }

        if ok {
            write "Test 8 (player spawn safe): OK";
        } else {
            write "Test 8 (player spawn safe): FAILED";
            tests_failed <- tests_failed + 1;
        }
    }

    // 9) One movement step must go to a neighbor and increment steps
    action test_player_step_is_neighbor {
        if (length(player) != 1) {
            write "Test 9 (player step neighbor): FAILED - no unique player to test";
            tests_failed <- tests_failed + 1;
            return;
        }

        player p <- one_of(player);
        gworld before <- p.current_cell;
        int before_steps <- p.steps;

        ask p { do move_randomly_one_step; }

        bool is_neighbor <- (p.current_cell in before.neighbors);
        bool steps_ok <- (p.steps = before_steps + 1);
        bool loc_ok <- (p.location = p.current_cell.location);

        if (is_neighbor and steps_ok and loc_ok) {
            write "Test 9 (player step neighbor): OK";
        } else {
            write "Test 9 (player step neighbor): FAILED";
            tests_failed <- tests_failed + 1;
        }

        // restore clean state for interactive debugging
        ask p { do respawn; }
    }

    // 10) Several steps in a row must always be neighbor moves (bounds-safe)
    action test_player_multiple_steps_are_neighbors {
        if (length(player) != 1) {
            write "Test 10 (player multi-step neighbor): FAILED - no unique player to test";
            tests_failed <- tests_failed + 1;
            return;
        }

        player p <- one_of(player);

        bool ok <- true;

        loop i from: 1 to: 20 {
            gworld before <- p.current_cell;
            ask p { do move_randomly_one_step; }

            if (!(p.current_cell in before.neighbors)) { ok <- false; }
            if (p.location != p.current_cell.location) { ok <- false; }
            if (!p.alive) { ok <- false; } // in normal test run, we don't want to die here
        }

        if ok {
            write "Test 10 (player multi-step neighbor): OK";
        } else {
            write "Test 10 (player multi-step neighbor): FAILED";
            tests_failed <- tests_failed + 1;
        }

        ask p { do respawn; }
    }

    // 11) Moving onto the Wumpus cell must mark the player as dead
    action test_player_death_detection {
        if (length(player) != 1) {
            write "Test 11 (player death detection): FAILED - no unique player to test";
            tests_failed <- tests_failed + 1;
            return;
        }

        gworld wcell <- one_of(gworld where each.has_wumpus);
        if (wcell = nil) {
            write "Test 11 (player death detection): FAILED - could not locate wumpus cell";
            tests_failed <- tests_failed + 1;
            return;
        }

        player p <- one_of(player);

        ask p {
            // force player onto wumpus cell and check death logic
            alive <- true;
            death_cause <- "none";
            current_cell <- wcell;
            location <- wcell.location;
            do check_lethal_cell;
        }

        if (!p.alive and p.death_cause = "wumpus") {
            write "Test 11 (player death detection): OK";
        } else {
            write "Test 11 (player death detection): FAILED";
            tests_failed <- tests_failed + 1;
        }

        ask p { do respawn; }
    }
}

// ============================================================
//                 GRID: WUMPUS WORLD CELLS
// ============================================================

grid gworld width: grid_width height: grid_height neighbors: 4 {

    // Content flags (true state of the world)
    bool has_pit    <- false;
    bool has_wumpus <- false;
    bool has_gold   <- false;

    // Percept flags (derived from neighbours)
    bool breeze <- false;   // pit nearby
    bool stench <- false;   // Wumpus nearby
    bool glow   <- false;   // gold nearby

    // Simple colouring: pits > Wumpus > gold > empty grass
    rgb color <- #green;

    reflex update_color {
        if has_pit {
            color <- #black;
        } else if has_wumpus {
            color <- #red;
        } else if has_gold {
            color <- #yellow;
        } else {
            color <- #green;
        }
    }
}

// ============================================================
//                 SPECIES: SMELLS / PERCEPTS
// ============================================================

species odorArea {
    aspect base {
        draw square(4) color: #brown border: #black;
    }
}

species glitterArea {
    aspect base {
        draw square(4) color: #chartreuse border: #black;
    }
}

species breezeArea {
    aspect base {
        draw square(4) color: #lightblue border: #black;
    }
}

// ============================================================
//                 SPECIES: WUMPUS, GOLD, PITS
// ============================================================

species wumpusArea {
    init { }
    aspect base  { draw square(4) color: #red border: #black; }
    aspect image { draw image("images/wumpus.png") size: {4,4}; }
}

species goldArea {
    init { }
    aspect base { draw square(4) color: #yellow border: #black; }
}

species pitArea {
    init { }
    aspect base { draw square(4) color: #black border: #white; }
}

// ============================================================
//                 SECTION 5: BASIC PLAYER AGENT
// ============================================================

species player skills: [moving] {

    // Minimal state (useful now + later for BDI)
    int  steps <- 0;
    bool alive <- true;

    string death_cause <- "none";   // "none" | "pit" | "wumpus"

    gworld spawn_cell   <- nil;
    gworld current_cell <- nil;
    gworld last_cell    <- nil;

    // Make sure any goto completes in a single tick for neighbor targets
    float speed <- 1000.0;

    action respawn {
        if (spawn_cell != nil) {
            steps <- 0;
            alive <- true;
            death_cause <- "none";

            current_cell <- spawn_cell;
            last_cell <- spawn_cell;
            location <- spawn_cell.location;
        }
    }

    action check_lethal_cell {
        if (current_cell != nil) {
            if (current_cell.has_pit) {
                alive <- false;
                death_cause <- "pit";
                write "PLAYER DIED: entered a PIT at " + location;
            } else if (current_cell.has_wumpus) {
                alive <- false;
                death_cause <- "wumpus";
                write "PLAYER DIED: entered the WUMPUS cell at " + location;
            }
        }
    }

    action move_randomly_one_step {

        if (!alive) { return; }
        if (current_cell = nil) { return; }

        list<gworld> neigh <- current_cell.neighbors;

        if (length(neigh) = 0) { return; } // should never happen in a normal grid
        gworld next_cell <- one_of(neigh);

        last_cell <- current_cell;
        current_cell <- next_cell;

        // Use moving skill (goto) + set discrete cell center
        do goto target: next_cell.location;
        location <- next_cell.location;

        steps <- steps + 1;

        if (debug_player) {
            write "Player step " + steps + " -> " + location;
        }

        do check_lethal_cell;
    }

    reflex random_walk {
        do move_randomly_one_step;
    }

    aspect base {
        rgb c <- #white;

        if (!alive) {
            c <- #gray;
        } else if (current_cell != nil and current_cell.stench) {
            c <- #orange;
        } else if (current_cell != nil and current_cell.breeze) {
            c <- #cyan;
        } else if (current_cell != nil and current_cell.glow) {
            c <- #chartreuse;
        }

        draw circle(2.2) color: c border: #black;
    }
}

// ============================================================
//                 EXPERIMENTS
// ============================================================

experiment Wumpus_experiment_1 type: gui {

    // Parameters visible in the GUI
    parameter "Grid width"  var: grid_width  min: 4 max: 50 step: 1;
    parameter "Grid height" var: grid_height min: 4 max: 50 step: 1;

    parameter "Number of pits (random map)" var: nb_pits min: 0 max: 50 step: 1;
    parameter "Number of gold areas"        var: nb_gold min: 0 max: 10 step: 1;

    parameter "Use random map (otherwise predefined example)" var: use_random_map;

    parameter "Debug player movement (console spam)" var: debug_player;

    output {
        display view1 {
            grid gworld border: #darkgreen;

            // background overlays
            species breezeArea  aspect: base;
            species odorArea    aspect: base;
            species glitterArea aspect: base;

            // objects
            species pitArea     aspect: base;
            species wumpusArea  aspect: base;
            species goldArea    aspect: base;

            // player on top
            species player      aspect: base;
        }

        monitor "Tests executed"          value: tests_executed;
        monitor "Number of failed tests"  value: tests_failed;
        monitor "Player count"            value: length(player);
    }
}

// Optional dedicated experiment that just reuses the same tests
experiment Wumpus_environment_tests type: gui {

    parameter "Use random map (otherwise predefined example)" var: use_random_map;

    output {
        display tests_view {
            grid gworld border: #gray;

            species breezeArea  aspect: base;
            species odorArea    aspect: base;
            species glitterArea aspect: base;

            species pitArea     aspect: base;
            species wumpusArea  aspect: base;
            species goldArea    aspect: base;

            species player      aspect: base;
        }

        monitor "Tests executed"          value: tests_executed;
        monitor "Number of failed tests"  value: tests_failed;
        monitor "Player count"            value: length(player);
    }
}
