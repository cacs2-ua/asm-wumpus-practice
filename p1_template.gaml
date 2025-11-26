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

    // ---------- BDI PREDICATES (global symbols) ----------
    string P_WANTS_PATROL       <- "wants_patrol";
    string P_WANTS_COLLECT_GOLD <- "wants_collect_gold";
    string P_WANTS_AVOID_WUMPUS <- "wants_avoid_wumpus";

    string P_NEAR_PIT    <- "near_pit";
    string P_NEAR_GOLD   <- "near_gold";
    string P_NEAR_WUMPUS <- "near_wumpus";

    // Desire-related predicates required by the practice
    predicate wants_patrol       <- new_predicate(P_WANTS_PATROL);
    predicate wants_collect_gold <- new_predicate(P_WANTS_COLLECT_GOLD);
    predicate wants_avoid_wumpus <- new_predicate(P_WANTS_AVOID_WUMPUS);

    // Transient perception predicates (near_x)
    predicate near_pit    <- new_predicate(P_NEAR_PIT);
    predicate near_gold   <- new_predicate(P_NEAR_GOLD);
    predicate near_wumpus <- new_predicate(P_NEAR_WUMPUS);
	


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

	    // ======================================================
    // UNIT TESTS — SECTION 6 (Beliefs)
    // ======================================================
    action assert_true (bool cond, string msg) {
        if (!cond) {
            tests_failed <- tests_failed + 1;
            write ("[FAIL] " + msg);
        } else {
            write ("[ OK ] " + msg);
        }
    }

    action run_bdi_belief_unit_tests {

        write "--------------------------------------------";
        write "RUNNING UNIT TESTS — Section 6 (Beliefs)";
        write "--------------------------------------------";

        int failed_before <- tests_failed;

        // Create a dedicated tester agent (won't walk randomly)
        create player number: 1 {
            is_tester <- true;
            alive <- true;
            location <- {5,5};   // assumes grid >= 6x6 (default 10x10 is OK)
        }

        player t <- one_of(player where each.is_tester);

        // reset belief structures + BDI belief base
		ask t {
		    self.MAX_RECENT_POS  <- 3;
		    self.MAX_SAFE_CELLS  <- 10;
		    self.MAX_EVIDENCE    <- 50;
		    self.MAX_GLOW_MEMORY <- 2;
		
		    self.recent_positions <- [];
		    self.known_safe <- [];
		    self.pit_evidence <- [];
		    self.wumpus_evidence <- [];
		
		    self.glow_mem_pos <- [];
		    self.glow_mem_candidates <- [];
		    self.glow_mem_step <- [];
		
		    self.belief_base <- [];
		}

        // -----------------------
        // TEST 1: recent_positions bounded queue
        // -----------------------
        ask t {
            recent_positions <- [];
            recent_positions <- recent_positions + [{0,0}];
            recent_positions <- recent_positions + [{0,1}];
            recent_positions <- recent_positions + [{0,2}];
            recent_positions <- recent_positions + [{0,3}];
            do enforce_memory_bounds;
        }

        do assert_true(length(t.recent_positions) = 3, "recent_positions is bounded to MAX_RECENT_POS");
        do assert_true(t.recent_positions[0] = {0,1}, "recent_positions forgets oldest entries");
        do assert_true(t.recent_positions[2] = {0,3}, "recent_positions keeps newest entries");

        // -----------------------
        // TEST 2: breeze -> pit evidence increments; no breeze clears neighbors
        // -----------------------
        list<point> neigh <- [{4,5},{6,5},{5,4},{5,6}];

        ask t {
            location <- {5,5};
            do update_beliefs_from_percepts(true, false, false);
        }

        loop p over: neigh {
            do assert_true(length(t.pit_evidence where (each = p)) = 1,
                           "breeze adds pit evidence for neighbor " + string(p));
        }

        do assert_true(length(t.belief_base where (each.predicate = near_pit)) > 0,
                       "near_pit predicate is added when breeze=true");

        ask t {
            do update_beliefs_from_percepts(false, false, false);
        }

        loop p over: neigh {
            do assert_true(length(t.pit_evidence where (each = p)) = 0,
                           "no breeze removes pit evidence for neighbor " + string(p));
        }

        do assert_true(length(t.belief_base where (each.predicate = near_pit)) = 0,
                       "near_pit predicate is removed when breeze=false");

        // -----------------------
        // TEST 3: glow memory bounded to MAX_GLOW_MEMORY
        // -----------------------
        ask t {
            location <- {2,2};
            do update_beliefs_from_percepts(false, false, true);

            location <- {3,3};
            do update_beliefs_from_percepts(false, false, true);

            location <- {4,4};
            do update_beliefs_from_percepts(false, false, true);
        }

        do assert_true(length(t.glow_mem_pos) = 2, "glow_mem_pos is bounded to MAX_GLOW_MEMORY");
        do assert_true(t.glow_mem_pos[0] = {3,3} and t.glow_mem_pos[1] = {4,4},
                       "glow memory keeps only the most recent cues");

        do assert_true(length(t.belief_base where (each.predicate = near_gold)) > 0,
                       "near_gold predicate is present after glow=true (last update)");

        // -----------------------
        // TEST 4: stench toggles near_wumpus predicate
        // -----------------------
        ask t { do update_beliefs_from_percepts(false, true, false); }
        do assert_true(length(t.belief_base where (each.predicate = near_wumpus)) > 0,
                       "near_wumpus predicate is added when stench=true");

        ask t { do update_beliefs_from_percepts(false, false, false); }
        do assert_true(length(t.belief_base where (each.predicate = near_wumpus)) = 0,
                       "near_wumpus predicate is removed when stench=false");

        // Cleanup tester
        ask t { do die; }

        int failed_now <- tests_failed - failed_before;
        write "--------------------------------------------";
        write ("UNIT TESTS FINISHED — new failures: " + string(failed_now));
        write "--------------------------------------------";
    }
	
	

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

        // ----- BDI Belief tests (Section 6) -----
        do run_bdi_belief_unit_tests;

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
// ============================================================
//                 SECTION 5 + SECTION 6: BDI PLAYER
// ============================================================

species player skills: [moving] control: simple_bdi {

    // ------------------------------
    // SECTION 5 (kept): minimal state
    // ------------------------------
    int  steps <- 0;
    bool alive <- true;

    string death_cause <- "none";   // "none" | "pit" | "wumpus"

    gworld spawn_cell   <- nil;
    gworld current_cell <- nil;
    gworld last_cell    <- nil;

    // Make sure any goto completes in a single tick for neighbor targets
    float speed <- 1000.0;

    // ------------------------------
    // SECTION 6: test helper flag
    // ------------------------------
    bool is_tester <- false;

    // ------------------------------
    // SECTION 6: bounded memory capacities
    // ------------------------------
    int MAX_RECENT_POS  <- 10;
    int MAX_SAFE_CELLS  <- 25;
    int MAX_EVIDENCE    <- 40;
    int MAX_GLOW_MEMORY <- 5;

    // ------------------------------
    // SECTION 6: extra self-state for later sections
    // ------------------------------
    point  prev_pos   <- {0,0};
    string last_move  <- "none";
    int    belief_step <- 0;

    // ------------------------------
    // SECTION 6: bounded belief structures
    // ------------------------------
    list<point> known_safe      <- [];
    list<point> recent_positions <- [];

    list<point> pit_evidence    <- [];
    list<point> wumpus_evidence <- [];

    list<point>        glow_mem_pos        <- [];
    list<list<point>>  glow_mem_candidates <- [];
    list<int>          glow_mem_step       <- [];

    // Transient perception snapshot (current tick)
    bool perc_breeze <- false;
    bool perc_stench <- false;
    bool perc_glow   <- false;

    list<point> cand_pit    <- [];
    list<point> cand_wumpus <- [];
    list<point> cand_gold   <- [];

    int risk_pit    <- 0;
    int risk_wumpus <- 0;

    // temp variables for helpers
    list<point> neighbors4_tmp <- [];
    int tmp_count <- 0;

    // ======================================================
    // Helper: compute Von Neumann neighbors (4-neighborhood)
    // ======================================================
    action compute_neighbors4 (point p) {
        list<point> n <- [];
        int x <- int(p.x);
        int y <- int(p.y);

        if (x - 1 >= 0)         { n <- n + [{x - 1, y}]; }
        if (x + 1 < grid_width) { n <- n + [{x + 1, y}]; }
        if (y - 1 >= 0)         { n <- n + [{x, y - 1}]; }
        if (y + 1 < grid_height){ n <- n + [{x, y + 1}]; }

        neighbors4_tmp <- n;
    }

    // ======================================================
    // Helper: enforce bounded memories
    // ======================================================
    action enforce_memory_bounds {

        int L;

        L <- length(recent_positions);
        if (L > MAX_RECENT_POS) {
            recent_positions <- recent_positions[(L - MAX_RECENT_POS) :: (L - 1)];
        }

        L <- length(known_safe);
        if (L > MAX_SAFE_CELLS) {
            known_safe <- known_safe[(L - MAX_SAFE_CELLS) :: (L - 1)];
        }

        L <- length(pit_evidence);
        if (L > MAX_EVIDENCE) {
            pit_evidence <- pit_evidence[(L - MAX_EVIDENCE) :: (L - 1)];
        }

        L <- length(wumpus_evidence);
        if (L > MAX_EVIDENCE) {
            wumpus_evidence <- wumpus_evidence[(L - MAX_EVIDENCE) :: (L - 1)];
        }

        L <- length(glow_mem_pos);
        if (L > MAX_GLOW_MEMORY) {
            int start <- L - MAX_GLOW_MEMORY;
            glow_mem_pos        <- glow_mem_pos[start :: (L - 1)];
            glow_mem_candidates <- glow_mem_candidates[start :: (L - 1)];
            glow_mem_step       <- glow_mem_step[start :: (L - 1)];
        }
    }

    // ======================================================
    // Helper: count evidence occurrences (suspicion score)
    // ======================================================
    action count_in_list (list<point> L, point p) {
        tmp_count <- length(L where (each = p));
    }

    // ======================================================
    // Helper: set/unset a transient BDI belief predicate
    // ======================================================
	action set_transient_belief (predicate pr, bool active) {
	    if (active) {
	        if (length(belief_base where (each.predicate = pr)) = 0) {
	            do add_belief(predicate: pr, strength: 1.0);
	        }
	    } else {
	        belief_base <- belief_base where (each.predicate != pr);
	    }
	}

    // ======================================================
    // SECTION 6 CORE: update beliefs from percepts
    // ======================================================
    action update_beliefs_from_percepts (bool breeze, bool stench, bool glow) {

        belief_step <- belief_step + 1;

        // memory of visited cells
        recent_positions <- recent_positions + [location];

        // neighbor candidates
        do compute_neighbors4(location);
        list<point> neigh <- neighbors4_tmp;

        // reset candidates
        cand_pit <- [];
        cand_wumpus <- [];
        cand_gold <- [];

        // (A) Breeze -> pit evidence
        if (breeze) {
            cand_pit <- neigh;
            loop p over: neigh {
                if (!(known_safe contains p)) {
                    pit_evidence <- pit_evidence + [p];
                }
            }
        } else {
            // no breeze => neighbors cannot contain pits
            loop p over: neigh {
                pit_evidence <- pit_evidence where (each != p);
            }
        }

        // (B) Stench -> wumpus evidence
        if (stench) {
            cand_wumpus <- neigh;
            loop p over: neigh {
                if (!(known_safe contains p)) {
                    wumpus_evidence <- wumpus_evidence + [p];
                }
            }
        } else {
            // no stench => neighbors cannot contain the Wumpus
            loop p over: neigh {
                wumpus_evidence <- wumpus_evidence where (each != p);
            }
        }

        // (C) Safe cells only if BOTH no breeze and no stench
        if (!breeze and !stench) {
            loop p over: neigh {
                if (!(known_safe contains p)) { known_safe <- known_safe + [p]; }
            }
        }

        // (D) Glow -> bounded glow memory
        if (glow) {
            cand_gold <- neigh;
            glow_mem_pos        <- glow_mem_pos + [location];
            glow_mem_candidates <- glow_mem_candidates + [neigh];
            glow_mem_step       <- glow_mem_step + [belief_step];
        }

        // (E) risk metrics (max evidence count among candidates)
        risk_pit <- 0;
        if (breeze) {
            loop p over: cand_pit {
                do count_in_list(pit_evidence, p);
                if (tmp_count > risk_pit) { risk_pit <- tmp_count; }
            }
        }

        risk_wumpus <- 0;
        if (stench) {
            loop p over: cand_wumpus {
                do count_in_list(wumpus_evidence, p);
                if (tmp_count > risk_wumpus) { risk_wumpus <- tmp_count; }
            }
        }

        // (F) enforce bounded memory
        do enforce_memory_bounds;

        // (G) transient predicates in belief_base
        do set_transient_belief(near_pit, breeze);
        do set_transient_belief(near_wumpus, stench);
        do set_transient_belief(near_gold, glow);
    }

    // ======================================================
    // SECTION 6 REQUIRED: perception handling via `perceive`
    // ======================================================
	action perceive_and_revise_beliefs {
	
	    perc_breeze <- false;
	    perc_stench <- false;
	    perc_glow   <- false;
	
	    gworld c <- one_of(gworld where (each.location = location));
	    if (c != nil) {
	        perc_breeze <- c.breeze;
	        perc_stench <- c.stench;
	        perc_glow   <- c.glow;
	    }
	
	    do update_beliefs_from_percepts(perc_breeze, perc_stench, perc_glow);
	}


    // ------------------------------
    // (kept): respawn + death check
    // ------------------------------
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

    // ------------------------------
    // (kept): random movement baseline
    // ------------------------------
    action move_randomly_one_step {

        if (!alive) { return; }
        if (current_cell = nil) { return; }

        list<gworld> neigh <- current_cell.neighbors;
        if (length(neigh) = 0) { return; }

        gworld next_cell <- one_of(neigh);

        // store previous position + move label (for later sections)
        prev_pos <- location;
        int dx <- int(next_cell.location.x) - int(current_cell.location.x);
        int dy <- int(next_cell.location.y) - int(current_cell.location.y);
        if (dx = 1) { last_move <- "E"; }
        else if (dx = -1) { last_move <- "W"; }
        else if (dy = 1) { last_move <- "S"; }
        else if (dy = -1) { last_move <- "N"; }
        else { last_move <- "none"; }

        last_cell <- current_cell;
        current_cell <- next_cell;

        do goto target: next_cell.location;
        location <- next_cell.location;

        steps <- steps + 1;

        if (debug_player) {
            write "Player step " + steps + " -> " + location;
        }

        do check_lethal_cell;
    }

    // One reflex does both: perceive first, then move
// ------------------------------
// BDI bootstrap: initial desire
// ------------------------------
init {
    // Simple baseline: just patrol (random walk)
    do add_desire(predicate: wants_patrol, strength: 1.0);
}

// ------------------------------
// BDI perception (runs each tick in simple_bdi)
// ------------------------------
plan patrol intention: wants_patrol {
    if (alive and (not is_tester)) {
        do perceive_and_revise_beliefs;   // <-- usa tu percepción manual (one_of gworld ...)
        do move_randomly_one_step;
    }
}

// ------------------------------
// BDI plan: patrol = random walk baseline
// ------------------------------
plan patrol intention: wants_patrol {
    if (alive and (not is_tester)) {
        do move_randomly_one_step;
    }
}



    // ------------------------------
    // (kept): appearance
    // ------------------------------
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
