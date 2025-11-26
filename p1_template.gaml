/**
 * Name: Practice 1 Wumpus - Environment + Basic Player + Tests
 * Author: Based on template by Raúl Fraile
 */

model Wumpus_template

global {

    // ---------- PARAMETERS FOR THE ENVIRONMENT ----------

    int grid_width <- 8;     // can be changed from the experiment
    int grid_height <- 8;

    int nb_gold <- 4;          // number of treasures (only used in random maps)
    int nb_pits <- 6;          // number of pits     (only used in random maps)

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
    
    bool tests_running <- false;

bool   game_finished <- false;
int    total_gold_init <- 0;

string end_outcome <- "";          // "VICTORY" | "GAME OVER"
string end_reason  <- "";          // "all_gold_collected" | "pit" | "wumpus"

int    end_cycle <- 0;
int    end_steps <- 0;

int    end_gold_total     <- 0;
int    end_gold_collected <- 0;

point  end_cell <- {0,0};
string end_intention <- "";

int end_known_safe     <- 0;
int end_forbidden      <- 0;
int end_pit_evidence   <- 0;
int end_wumpus_evidence<- 0;

action reset_end_state {
    game_finished <- false;

    end_outcome <- "";
    end_reason  <- "";

    end_cycle <- 0;
    end_steps <- 0;

    end_gold_total     <- total_gold_init;
    end_gold_collected <- 0;

    end_cell <- {0,0};
    end_intention <- "";

    end_known_safe      <- 0;
    end_forbidden       <- 0;
    end_pit_evidence    <- 0;
    end_wumpus_evidence <- 0;
}

action end_game (string outcome, string reason) {

    if (game_finished) { return; }

    game_finished <- true;

    end_outcome <- outcome;
    end_reason  <- reason;

    end_cycle <- cycle;

    end_gold_total     <- total_gold_init;
    end_gold_collected <- total_gold_init - length(goldArea);

    player p <- one_of(player where (!each.is_tester));
    if (p != nil) {

        end_steps <- p.steps;

        if (p.current_cell != nil) {
            end_cell <- { int(p.current_cell.grid_x), int(p.current_cell.grid_y) };
        } else {
            end_cell <- { int(p.location.x), int(p.location.y) };
        }

        end_intention <- p.current_intention;

        end_known_safe      <- length(p.known_safe);
        end_forbidden       <- length(p.forbidden_cells);
        end_pit_evidence    <- length(p.pit_evidence);
        end_wumpus_evidence <- length(p.wumpus_evidence);
    }

    do pause;
}

reflex check_end_conditions when: (!tests_running) and (!game_finished) {

    player p <- one_of(player where (!each.is_tester));

    // 1) Death => GAME OVER (priority)
    if (p != nil and !p.alive) {
        do end_game("GAME OVER", p.death_cause);
        return;
    }

    // 2) All gold collected => VICTORY
    if (length(goldArea) = 0) {
        do end_game("VICTORY", "all_gold_collected");
        return;
    }
}

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
	    ask player      { do die; }
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
	
	    // 4) End-game bookkeeping (MUST be after the map is created)
	    total_gold_init <- length(goldArea);
	    do reset_end_state;
	}

    // ============================================================
    //                 SECTION 5: PLAYER CREATION
    // ============================================================

action setup_player {

    // Prefer a start that is safe AND has no immediate danger cues (no breeze, no stench)
    list<gworld> safe_no_cues <- gworld where ( (!(each.has_pit or each.has_wumpus)) and (!(each.breeze or each.stench)) );

    list<gworld> safe_cells <- (length(safe_no_cues) > 0)
        ? safe_no_cues
        : (gworld where (!(each.has_pit or each.has_wumpus)));

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
    
    
    action rebuild_gold_percepts {

    // Clear gold + glow and remove current glow overlays
    ask gworld {
        has_gold <- false;
        glow <- false;
    }
    ask glitterArea { do die; }

    // Rebuild from current goldArea agents
    ask goldArea {

        // Find the underlying grid cell at the same location
        gworld gc <- one_of(gworld where (each.location = location));

        if (gc != nil) {
            ask gc { has_gold <- true; }

            list<gworld> neigh <- [];
            ask gc { neigh <- neighbors; }

            loop c over: neigh {
                ask c { glow <- true; }
                create glitterArea { location <- c.location; }
            }
        }
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
		
		    spawn_cell   <- gworld grid_at {5,5};
		    current_cell <- spawn_cell;
		    last_cell    <- spawn_cell;
		
		    if (current_cell != nil) {
		        location <- current_cell.location;
		    }
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
		do assert_true(first(t.recent_positions) = point(0,1), "recent_positions forgets oldest entries");
		do assert_true(last(t.recent_positions)  = point(0,3), "recent_positions keeps newest entries");


        // -----------------------
        // TEST 2: breeze -> pit evidence increments; no breeze clears neighbors
        // -----------------------
        list<point> neigh <- [{4,5},{6,5},{5,4},{5,6}];

		ask t {
		    gworld c <- gworld grid_at {5,5};
		    current_cell <- c;
		    location <- c.location;
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
		    gworld c1 <- gworld grid_at {2,2};
		    current_cell <- c1; location <- c1.location;
		    do update_beliefs_from_percepts(false, false, true);
		
		    gworld c2 <- gworld grid_at {3,3};
		    current_cell <- c2; location <- c2.location;
		    do update_beliefs_from_percepts(false, false, true);
		
		    gworld c3 <- gworld grid_at {4,4};
		    current_cell <- c3; location <- c3.location;
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
    
    // ======================================================
// UNIT TESTS — SECTION 7 (Desires)
// ======================================================
action run_bdi_desire_unit_tests {

    write "--------------------------------------------";
    write "RUNNING UNIT TESTS — Section 7 (Desires)";
    write "--------------------------------------------";

    int failed_before <- tests_failed;

    // Pick a robust "center" cell (works for any grid >= 2x2)
    int cx <- max(1, int(grid_width / 2));
    int cy <- max(1, int(grid_height / 2));

    if (cx >= grid_width)  { cx <- grid_width - 1; }
    if (cy >= grid_height) { cy <- grid_height - 1; }

    gworld center <- gworld grid_at {cx, cy};
    if (center = nil) {
        do assert_true(false, "Section 7 tests skipped: could not get a center grid cell.");
        return;
    }

    // Create a dedicated tester agent (won't execute plans)
    create player number: 1 {
        is_tester <- true;
        alive <- true;

        spawn_cell   <- center;
        current_cell <- center;
        last_cell    <- center;

        location <- center.location;
    }

    player t <- one_of(player where each.is_tester);

    // -----------------------
    // TEST 1: default desire = patrol only
    // -----------------------
    ask t {
        desire_base <- [];
        perc_breeze <- false;
        perc_stench <- false;
        perc_glow   <- false;

        collect_persist <- 0;
        avoid_persist <- 0;

        glow_mem_pos <- [];
        glow_mem_candidates <- [];
        glow_mem_step <- [];

        pit_evidence <- [];
        wumpus_evidence <- [];
        known_safe <- [];
        recent_positions <- [];

        do update_desires_from_beliefs;
    }

    do assert_true(length(t.desire_base where (each.predicate = wants_patrol)) > 0,
        "Default: wants_patrol is present");
    do assert_true(length(t.desire_base where (each.predicate = wants_collect_gold)) = 0,
        "Default: wants_collect_gold is not active");
    do assert_true(length(t.desire_base where (each.predicate = wants_avoid_wumpus)) = 0,
        "Default: wants_avoid_wumpus is not active");

    // -----------------------
    // TEST 2: glow activates collect_gold (when no danger)
    // -----------------------
    ask t {
        perc_breeze <- false;
        perc_stench <- false;
        perc_glow   <- true;
        do update_desires_from_beliefs;
    }

    do assert_true(length(t.desire_base where (each.predicate = wants_collect_gold)) > 0,
        "Glow: wants_collect_gold becomes active");
    do assert_true(length(t.desire_base where (each.predicate = wants_avoid_wumpus)) = 0,
        "Glow only: wants_avoid_wumpus stays inactive");

    // -----------------------
    // TEST 3: memory-based collect_gold (no glow now, but glow_mem exists)
    // -----------------------
    ask t {
        perc_glow <- false;
        glow_mem_pos <- glow_mem_pos + [{cx, cy}];
        do update_desires_from_beliefs;
    }

    do assert_true(length(t.desire_base where (each.predicate = wants_collect_gold)) > 0,
        "Glow memory: wants_collect_gold remains active even without current glow");

    // -----------------------
    // TEST 4: danger overrides collect (priority policy)
    // -----------------------
    ask t {
        perc_glow <- true;
        perc_breeze <- true;   // danger cue
        perc_stench <- false;
        do update_desires_from_beliefs;
    }

    do assert_true(length(t.desire_base where (each.predicate = wants_avoid_wumpus)) > 0,
        "Breeze+Glow: wants_avoid_wumpus becomes active");
    do assert_true(length(t.desire_base where (each.predicate = wants_collect_gold)) = 0,
        "Breeze+Glow: wants_collect_gold is suppressed by danger priority");

    // -----------------------
    // TEST 5: patrol next-cell selection avoids a highly risky neighbor
    // Build a controlled case: two safe neighbors, one is made risky by evidence
    // -----------------------
    int east_x <- cx + 1;
    int west_x <- cx - 1;

    if (east_x < grid_width and west_x >= 0) {

        ask t {
            current_cell <- center;
            location <- center.location;

            known_safe <- [{west_x, cy}, {east_x, cy}];

            // Make EAST risky: repeated evidence >= RISK_THRESHOLD
            pit_evidence <- [{east_x, cy}, {east_x, cy}];

            do select_patrol_next_cell;
        }

        do assert_true(t.patrol_next_cell != nil, "Patrol selection returns a next cell");
        do assert_true(int(t.patrol_next_cell.grid_x) = west_x and int(t.patrol_next_cell.grid_y) = cy,
            "Patrol selection avoids risky neighbor (chooses WEST in this controlled setup)");

    } else {
        write "[INFO] Patrol selection test skipped (grid too small for east+west neighbors).";
    }

    // Cleanup tester
    ask t { do die; }

    int failed_now <- tests_failed - failed_before;
    write "--------------------------------------------";
    write ("UNIT TESTS FINISHED — new failures: " + string(failed_now));
    write "--------------------------------------------";
}

// ======================================================
// UNIT TESTS — SECTION 8 (Intentions & Plans)
// ======================================================
// ======================================================
// UNIT TESTS — SECTION 8 (Intentions & Plans)
// ======================================================
action run_bdi_intention_unit_tests {

    write "--------------------------------------------";
    write "RUNNING UNIT TESTS — Section 8 (Intentions & Plans)";
    write "--------------------------------------------";

    int failed_before <- tests_failed;

    int cx <- max(1, int(grid_width / 2));
    int cy <- max(1, int(grid_height / 2));

    if (cx >= grid_width)  { cx <- grid_width - 1; }
    if (cy >= grid_height) { cy <- grid_height - 1; }

    gworld center <- gworld grid_at {cx, cy};
    if (center = nil) {
        do assert_true(false, "Section 8 tests skipped: could not get a center grid cell.");
        return;
    }

    create player number: 1 {
        is_tester <- true;
        alive <- true;

        spawn_cell   <- center;
        current_cell <- center;
        last_cell    <- center;
        location     <- center.location;

        current_intention <- "I_PATROL";
        intention_age <- 999;

        forbidden_cells <- [];

        desire_base <- [];
        belief_base <- [];

        perc_breeze <- false;
        perc_stench <- false;
        perc_glow   <- false;

        collect_persist <- 0;
        avoid_persist <- 0;

        glow_mem_pos <- [];
        glow_mem_candidates <- [];
        glow_mem_step <- [];

        pit_evidence <- [];
        wumpus_evidence <- [];
        known_safe <- [];
        recent_positions <- [];
    }

    player t <- one_of(player where each.is_tester);

    // TEST 1: No cues => PATROL
    ask t {
        current_intention <- "I_PATROL"; intention_age <- 999;
        perc_breeze <- false; perc_stench <- false; perc_glow <- false;
        collect_persist <- 0; avoid_persist <- 0;
        glow_mem_pos <- []; glow_mem_candidates <- []; glow_mem_step <- [];
        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_PATROL", "No cues: current intention is I_PATROL");

    // TEST 2: Glow (no danger) => GET_GOLD
    ask t {
        current_intention <- "I_PATROL"; intention_age <- 999;
        perc_breeze <- false; perc_stench <- false; perc_glow <- true;
        avoid_persist <- 0;
        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_GET_GOLD", "Glow only: current intention is I_GET_GOLD");

    // TEST 3: Breeze => ESCAPE_PIT
    ask t {
        current_intention <- "I_PATROL"; intention_age <- 999;
        perc_breeze <- true; perc_stench <- false; perc_glow <- false;
        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_ESCAPE_PIT", "Breeze: current intention is I_ESCAPE_PIT");

    // TEST 4: Stench => ESCAPE_WUMPUS
    // (Resetting intention avoids the escape-inertia from the previous test affecting this one.)
    ask t {
        current_intention <- "I_PATROL"; intention_age <- 999;
        perc_breeze <- false; perc_stench <- true; perc_glow <- false;
        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_ESCAPE_WUMPUS", "Stench: current intention is I_ESCAPE_WUMPUS");

    // TEST 5: Breeze + Stench (+Glow) => ESCAPE_WUMPUS
    ask t {
        current_intention <- "I_PATROL"; intention_age <- 999;
        perc_breeze <- true; perc_stench <- true; perc_glow <- true;
        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_ESCAPE_WUMPUS",
        "Breeze+Stench(+Glow): current intention prioritizes I_ESCAPE_WUMPUS");

    // TEST 6: Glow memory (no current glow) => GET_GOLD
    ask t {
        current_intention <- "I_PATROL"; intention_age <- 999;
        perc_breeze <- false; perc_stench <- false; perc_glow <- false;
        collect_persist <- 0; avoid_persist <- 0;

        glow_mem_pos <- [{cx, cy}];
        glow_mem_candidates <- [[{cx, cy}]];
        glow_mem_step <- [0];

        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_GET_GOLD",
        "Glow memory: current intention is I_GET_GOLD even without current perc_glow");

    // TEST 7: Danger preempts gold immediately
    ask t {
        current_intention <- "I_GET_GOLD";
        intention_age <- 0;

        perc_breeze <- true; perc_stench <- false; perc_glow <- false;

        do update_desires_from_beliefs;
        do select_intention;
    }
    do assert_true(t.current_intention = "I_ESCAPE_PIT",
        "Preemption: breeze interrupts I_GET_GOLD -> I_ESCAPE_PIT");

    ask t { do die; }

    int failed_now <- tests_failed - failed_before;
    write "--------------------------------------------";
    write ("UNIT TESTS FINISHED — new failures: " + string(failed_now));
    write "--------------------------------------------";
}


    
	
	

action run_unit_tests {

    tests_running <- true;

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

    // ----- BDI tests (Sections 6–8) -----
    do run_bdi_belief_unit_tests;
    do run_bdi_desire_unit_tests;
    do run_bdi_intention_unit_tests;

    if (tests_failed = 0) {
        write "All tests PASSED";
    } else {
        write "Tests FAILED. Number of failed tests: " + tests_failed;
    }

    write "============================";

    tests_running <- false;
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
	
	        if (before = nil or p.current_cell = nil) { ok <- false; }
	        else if (!(p.current_cell in before.neighbors)) { ok <- false; }
	
	        if (p.location != p.current_cell.location) { ok <- false; }
	
	        // Important: in random maps it is normal to sometimes die during a random walk.
	        // This test is about "neighbor move correctness", not "survival".
	        // If we die, respawn to keep testing additional neighbor moves.
	        if (!p.alive) {
	            ask p { do respawn; }
	        }
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

    if (length(recent_positions) > MAX_RECENT_POS) {
        recent_positions <- last(MAX_RECENT_POS, recent_positions);
    }

    if (length(known_safe) > MAX_SAFE_CELLS) {
        known_safe <- last(MAX_SAFE_CELLS, known_safe);
    }

    if (length(pit_evidence) > MAX_EVIDENCE) {
        pit_evidence <- last(MAX_EVIDENCE, pit_evidence);
    }

    if (length(wumpus_evidence) > MAX_EVIDENCE) {
        wumpus_evidence <- last(MAX_EVIDENCE, wumpus_evidence);
    }

    if (length(glow_mem_pos) > MAX_GLOW_MEMORY) {
        glow_mem_pos        <- last(MAX_GLOW_MEMORY, glow_mem_pos);
        glow_mem_candidates <- last(MAX_GLOW_MEMORY, glow_mem_candidates);
        glow_mem_step       <- last(MAX_GLOW_MEMORY, glow_mem_step);
    }

    if (length(forbidden_cells) > MAX_FORBIDDEN) {
        forbidden_cells <- last(MAX_FORBIDDEN, forbidden_cells);
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

    if (current_cell = nil) { return; }

    point here <- { int(current_cell.grid_x), int(current_cell.grid_y) };

    // Current cell is guaranteed safe (we are alive on it)
    if (!(known_safe contains here)) { known_safe <- known_safe + [here]; }

    recent_positions <- recent_positions + [here];

    do compute_neighbors4(here);
    list<point> neigh <- neighbors4_tmp;

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
        loop p over: neigh {
            wumpus_evidence <- wumpus_evidence where (each != p);
        }
    }

    // (C) If BOTH no breeze and no stench, all neighbors are safe
    if (!breeze and !stench) {
        loop p over: neigh {
            if (!(known_safe contains p)) { known_safe <- known_safe + [p]; }
        }
    }

    // (D) Glow memory
    if (glow) {
        cand_gold <- neigh;
        glow_mem_pos        <- glow_mem_pos + [here];
        glow_mem_candidates <- glow_mem_candidates + [neigh];
        glow_mem_step       <- glow_mem_step + [belief_step];
    }

    // (E) risk metrics
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

    do enforce_memory_bounds;

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
	
	    if (current_cell != nil) {
	        perc_breeze <- current_cell.breeze;
	        perc_stench <- current_cell.stench;
	        perc_glow   <- current_cell.glow;
	    }
	
	    do update_beliefs_from_percepts(perc_breeze, perc_stench, perc_glow);
	}
	
	// ======================================================
// SECTION 7: DESIRES (activation, persistence, priority)
// ======================================================
int RISK_THRESHOLD <- 2;              // evidence count >= 2 => "too risky"
int COLLECT_PERSIST_TICKS <- 3;       // keep collect desire active for a few ticks
int AVOID_PERSIST_TICKS   <- 1;       // keep avoid desire active for at least 1 extra tick

int collect_persist <- 0;
int avoid_persist   <- 0;

// helper output for tests / debugging
gworld patrol_next_cell <- nil;

// ======================================================
// SECTION 8: INTENTIONS (explicit) + plan execution
// ======================================================
string I_ESCAPE_PIT    <- "I_ESCAPE_PIT";
string I_ESCAPE_WUMPUS <- "I_ESCAPE_WUMPUS";
string I_GET_GOLD      <- "I_GET_GOLD";
string I_PATROL        <- "I_PATROL";

string current_intention <- I_PATROL;
int    intention_age     <- 0;

// Intention inertia (anti-thrashing)
int INTENTION_MIN_ESCAPE_TICKS <- 1;
int INTENTION_MIN_GOLD_TICKS   <- 3;

// Cell-level "do not re-enter" heuristic after an escape
int MAX_FORBIDDEN <- 20;
list<point> forbidden_cells <- [];


// --- helper: add/remove a desire cleanly (avoid duplicates)
action set_desire (predicate pr, bool active, float strength_val) {

    // Remove any existing instance of that desire
    desire_base <- desire_base where (each.predicate != pr);

    // Add it back only if active
    if (active) {
        do add_desire(predicate: pr, strength: strength_val);
    }
}

// --- helper: compute local max risks from stored evidence (even when no cue this tick)
action compute_local_risks_from_evidence (point here) {

    do compute_neighbors4(here);
    list<point> neigh <- neighbors4_tmp;

    risk_pit <- 0;
    risk_wumpus <- 0;

    loop p over: neigh {
        int pit_cnt <- length(pit_evidence where (each = p));
        int w_cnt   <- length(wumpus_evidence where (each = p));

        if (pit_cnt > risk_pit) { risk_pit <- pit_cnt; }
        if (w_cnt   > risk_wumpus) { risk_wumpus <- w_cnt; }
    }
}

// --- SECTION 7 CORE: beliefs -> desires mapping + prioritization
action update_desires_from_beliefs {

    if (current_cell = nil) { return; }

    // persistence bookkeeping
    if (perc_glow) { collect_persist <- COLLECT_PERSIST_TICKS; }
    else if (collect_persist > 0) { collect_persist <- collect_persist - 1; }

    if (perc_breeze or perc_stench) { avoid_persist <- AVOID_PERSIST_TICKS; }
    else if (avoid_persist > 0) { avoid_persist <- avoid_persist - 1; }

    point here <- { int(current_cell.grid_x), int(current_cell.grid_y) };

    // compute risk from evidence lists
    do compute_local_risks_from_evidence(here);

    // --- activation conditions
    bool danger_active <- (perc_breeze or perc_stench)
                        or (avoid_persist > 0)
                        or (risk_pit >= RISK_THRESHOLD)
                        or (risk_wumpus >= RISK_THRESHOLD);

    bool collect_active <- (!danger_active)
                        and (perc_glow or (length(glow_mem_pos) > 0) or (collect_persist > 0));

    // --- priorities via desire strengths: Avoid > Collect > Patrol
    float s_avoid  <- danger_active  ? 1.0 : 0.0;
    float s_collect<- collect_active ? 0.8 : 0.0;

    // patrol always exists as fallback, but weaker if other goals are active
    float s_patrol <- (danger_active or collect_active) ? 0.1 : 0.4;

    // enforce the policy in the desire base
    do set_desire(wants_avoid_wumpus, danger_active, s_avoid);

    // IMPORTANT: when danger is active, suppress collect_gold completely (no oscillation)
    do set_desire(wants_collect_gold, collect_active, s_collect);

    do set_desire(wants_patrol, true, s_patrol);
}

// ======================================================
// SECTION 7: PATROL PLAN (safe exploration step)
// ======================================================
action select_patrol_next_cell {

    patrol_next_cell <- nil;

    if (current_cell = nil) { return; }

    list<gworld> neigh <- current_cell.neighbors;
    if (length(neigh) = 0) { return; }

    bool in_2cycle <- false;
    if (length(recent_positions) >= 3) {
        list<point> tail3 <- last(3, recent_positions);
        if (length(tail3) = 3 and tail3[0] = tail3[2]) { in_2cycle <- true; }
    }

    list<gworld> safe_not_recent <- [];
    list<gworld> safe_any <- [];

    loop c over: neigh {
        point p <- { int(c.grid_x), int(c.grid_y) };

        // "forbidden" is ONLY for unknown/suspected cells; never block a known-safe cell
        bool is_forbidden <- (forbidden_cells contains p) and !(known_safe contains p);

        if ((known_safe contains p) and !is_forbidden) {
            safe_any <- safe_any + [c];
            if (!(recent_positions contains p)) { safe_not_recent <- safe_not_recent + [c]; }
        }
    }

    // Anti A<->B oscillation only when we have alternatives
    if (in_2cycle and last_cell != nil and length(safe_any) > 1) {
        safe_any <- safe_any where (each != last_cell);
        safe_not_recent <- safe_not_recent where (each != last_cell);
    } else if (last_cell != nil) {
        if (length(safe_any) > 1) { safe_any <- safe_any where (each != last_cell); }
        if (length(safe_not_recent) > 1) { safe_not_recent <- safe_not_recent where (each != last_cell); }
    }

    if (length(safe_not_recent) > 0) { patrol_next_cell <- one_of(safe_not_recent); return; }
    if (length(safe_any) > 0)        { patrol_next_cell <- one_of(safe_any);        return; }

    // Hard fallback: backtrack to last_cell if it is known safe (even if it was previously "forbidden")
    if (last_cell != nil and (last_cell in neigh)) {
        point back_p <- { int(last_cell.grid_x), int(last_cell.grid_y) };
        if (known_safe contains back_p) { patrol_next_cell <- last_cell; }
    }
}



action move_to_cell (gworld dest) {

    if (!alive) { return; }
    if (current_cell = nil) { return; }
    if (dest = nil) { return; }

    point dest_p <- { int(dest.grid_x), int(dest.grid_y) };

    // STRICT SAFETY: never enter an UNKNOWN cell if we have ANY pit/wumpus evidence on it
    bool is_unknown_cell <- !(known_safe contains dest_p);
    bool is_gold_cell <- dest.has_gold;

    int pit_cnt <- length(pit_evidence where (each = dest_p));
    int w_cnt   <- length(wumpus_evidence where (each = dest_p));

    bool blocked <- (is_unknown_cell and !is_gold_cell) and ((pit_cnt > 0) or (w_cnt > 0));

    if (blocked) {
        do add_forbidden_cell(dest_p);
        if (debug_player) {
            write "BLOCKED MOVE to " + dest.location + " (unknown + evidence: pit=" + string(pit_cnt) + ", wumpus=" + string(w_cnt) + ")";
        }
        return;
    }

    gworld from <- current_cell;

    prev_pos <- location;

    int dx <- int(dest.grid_x) - int(from.grid_x);
    int dy <- int(dest.grid_y) - int(from.grid_y);

    if (dx = 1) { last_move <- "E"; }
    else if (dx = -1) { last_move <- "W"; }
    else if (dy = 1) { last_move <- "S"; }
    else if (dy = -1) { last_move <- "N"; }
    else { last_move <- "none"; }

    last_cell <- from;
    current_cell <- dest;

    do goto target: dest.location;
    location <- dest.location;

    steps <- steps + 1;

    if (debug_player) {
        write "Player step " + steps + " -> " + location + " | intention=" + current_intention;
    }

    do check_lethal_cell;
    if (alive) { do collect_gold_if_present; }
}




action move_patrol_safe_one_step {
    do select_patrol_next_cell;
    if (patrol_next_cell != nil) {
        do move_to_cell(patrol_next_cell);
    }
}

// Minimal “collect” behavior for Section 7 (just bias movement near glow cues)
action move_collect_gold_one_step {

    if (current_cell = nil) { return; }

    bool in_2cycle <- false;
    if (length(recent_positions) >= 3) {
        list<point> tail3 <- last(3, recent_positions);
        if (length(tail3) = 3 and tail3[0] = tail3[2]) { in_2cycle <- true; }
    }

    list<point> targets <- [];
    if (perc_glow) {
        targets <- cand_gold;
    } else if (length(glow_mem_candidates) > 0) {
        targets <- glow_mem_candidates[length(glow_mem_candidates) - 1];
    }

    list<gworld> neigh <- current_cell.neighbors;

    list<gworld> preferred_safe <- [];

    loop c over: neigh {
        point p <- { int(c.grid_x), int(c.grid_y) };

        bool target_ok <- (targets contains p) or c.has_gold;
        bool safe_ok   <- (known_safe contains p) or c.has_gold;

        // forbidden only applies to unknown/suspected cells
        bool is_forbidden <- (forbidden_cells contains p) and !(known_safe contains p);

        if (target_ok and safe_ok and !is_forbidden) {
            preferred_safe <- preferred_safe + [c];
        }
    }

    if (in_2cycle and last_cell != nil and length(preferred_safe) > 1) {
        preferred_safe <- preferred_safe where (each != last_cell);
    } else if (last_cell != nil and length(preferred_safe) > 1) {
        preferred_safe <- preferred_safe where (each != last_cell);
    }

    if (length(preferred_safe) > 0) {
        do move_to_cell(one_of(preferred_safe));
        return;
    }

    do move_patrol_safe_one_step;
}



// Minimal “avoid” behavior for Section 7 (reactive backtrack; refined in Section 8)
action move_avoid_hazard_one_step {

    if (current_cell = nil) { return; }

    // Backtrack only if it does not create a forbidden 2-cycle
    if (last_cell != nil and (last_cell in current_cell.neighbors) and (last_cell != current_cell)) {
        point back_p <- { int(last_cell.grid_x), int(last_cell.grid_y) };
        if (!(forbidden_cells contains back_p)) {
            do move_to_cell(last_cell);
            return;
        }
    }

    do move_patrol_safe_one_step;
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
    
    action add_forbidden_cell(point p) {
    if (!(forbidden_cells contains p)) {
        forbidden_cells <- forbidden_cells + [p];
    }
    if (length(forbidden_cells) > MAX_FORBIDDEN) {
        forbidden_cells <- last(MAX_FORBIDDEN, forbidden_cells);
    }
}

action purge_glow_memory_of_point(point q) {

    if (length(glow_mem_pos) = 0) { return; }

    list<point> new_pos <- [];
    list<list<point>> new_cand <- [];
    list<int> new_step <- [];

    int n <- length(glow_mem_pos);

    loop i from: 0 to: (n - 1) {
        bool keep <- true;

        if (glow_mem_pos[i] = q) { keep <- false; }
        else if (glow_mem_candidates[i] contains q) { keep <- false; }

        if (keep) {
            new_pos  <- new_pos  + [glow_mem_pos[i]];
            new_cand <- new_cand + [glow_mem_candidates[i]];
            new_step <- new_step + [glow_mem_step[i]];
        }
    }

    glow_mem_pos        <- new_pos;
    glow_mem_candidates <- new_cand;
    glow_mem_step       <- new_step;
}

action collect_gold_if_present {

    if (current_cell = nil) { return; }

    if (current_cell.has_gold) {

        point here <- { int(current_cell.grid_x), int(current_cell.grid_y) };

        // Remove gold object at this cell
        ask goldArea where (each.location = current_cell.location) { do die; }

        // Rebuild gold flags + glow overlays to keep the world consistent
        ask world { do rebuild_gold_percepts; }

        // Clean internal memory so we do not keep chasing this gold
        do purge_glow_memory_of_point(here);

        if (debug_player) {
            write "GOLD COLLECTED at " + current_cell.location;
        }
    }
}

action select_and_update_intention {

    string proposed <- I_PATROL;

    bool danger_pit    <- perc_breeze or (risk_pit >= RISK_THRESHOLD);
    bool danger_wumpus <- perc_stench or (risk_wumpus >= RISK_THRESHOLD);

    // Priority: safety first. If both dangers, tie -> Wumpus.
    if (danger_pit or danger_wumpus) {
        if (danger_wumpus and (!danger_pit or (risk_wumpus >= risk_pit))) {
            proposed <- I_ESCAPE_WUMPUS;
        } else {
            proposed <- I_ESCAPE_PIT;
        }
    } else {
        bool gold_active <- perc_glow or (length(glow_mem_pos) > 0) or (collect_persist > 0);
        proposed <- gold_active ? I_GET_GOLD : I_PATROL;
    }

    // Inertia: keep escape for at least 1 tick
    if ((current_intention = I_ESCAPE_PIT or current_intention = I_ESCAPE_WUMPUS)
        and intention_age < INTENTION_MIN_ESCAPE_TICKS) {
        proposed <- current_intention;
    }

    // Inertia: keep gold pursuit for a few ticks unless danger appears
    if (current_intention = I_GET_GOLD
        and proposed = I_PATROL
        and intention_age < INTENTION_MIN_GOLD_TICKS
        and (length(glow_mem_pos) > 0 or collect_persist > 0)) {
        proposed <- I_GET_GOLD;
    }

    if (proposed != current_intention) {
        current_intention <- proposed;
        intention_age <- 0;
    } else {
        intention_age <- intention_age + 1;
    }
}

action select_intention {
    do select_and_update_intention;
}

action plan_escape_pit_one_step {

    if (current_cell = nil) { return; }

    // Detect A<->B oscillation from position history
    bool in_2cycle <- false;
    if (length(recent_positions) >= 3) {
        list<point> tail3 <- last(3, recent_positions);
        if (length(tail3) = 3 and tail3[0] = tail3[2]) { in_2cycle <- true; }
    }

    bool last_is_danger <- false;
    if (last_cell != nil) { last_is_danger <- last_cell.breeze or last_cell.stench; }

    // If backtracking keeps us in danger OR we are in a 2-cycle, try another known-safe neighbor first
    bool avoid_backtrack <- in_2cycle or (perc_breeze and last_is_danger);

    list<gworld> safe_no_cues <- [];
    list<gworld> safe_any <- [];

    list<gworld> neigh <- current_cell.neighbors;

    loop c over: neigh {
        point p <- { int(c.grid_x), int(c.grid_y) };
        if (known_safe contains p) {

            // Skip immediate backtrack only if we have an oscillation-risk
            if (avoid_backtrack and last_cell != nil and c = last_cell) {
                // do nothing
            } else {
                safe_any <- safe_any + [c];
                if (!(c.breeze or c.stench)) { safe_no_cues <- safe_no_cues + [c]; }
            }
        }
    }

    if (length(safe_no_cues) > 0) { do move_to_cell(one_of(safe_no_cues)); return; }
    if (length(safe_any) > 0)     { do move_to_cell(one_of(safe_any));     return; }

    // Fallback: backtrack to known-safe last_cell
    if (last_cell != nil and (last_cell in neigh) and (last_cell != current_cell)) {
        point back_p <- { int(last_cell.grid_x), int(last_cell.grid_y) };
        if (known_safe contains back_p) {
            do move_to_cell(last_cell);
            return;
        }
    }

    do move_patrol_safe_one_step;
}



action plan_escape_wumpus_one_step {

    if (current_cell = nil) { return; }

    // Detect A<->B oscillation from position history
    bool in_2cycle <- false;
    if (length(recent_positions) >= 3) {
        list<point> tail3 <- last(3, recent_positions);
        if (length(tail3) = 3 and tail3[0] = tail3[2]) { in_2cycle <- true; }
    }

    bool last_is_danger <- false;
    if (last_cell != nil) { last_is_danger <- last_cell.breeze or last_cell.stench; }

    // If backtracking keeps us in danger OR we are in a 2-cycle, try another known-safe neighbor first
    bool avoid_backtrack <- in_2cycle or (perc_stench and last_is_danger);

    list<gworld> safe_no_cues <- [];
    list<gworld> safe_any <- [];

    list<gworld> neigh <- current_cell.neighbors;

    loop c over: neigh {
        point p <- { int(c.grid_x), int(c.grid_y) };
        if (known_safe contains p) {

            // Skip immediate backtrack only if we have an oscillation-risk
            if (avoid_backtrack and last_cell != nil and c = last_cell) {
                // do nothing
            } else {
                safe_any <- safe_any + [c];
                if (!(c.breeze or c.stench)) { safe_no_cues <- safe_no_cues + [c]; }
            }
        }
    }

    if (length(safe_no_cues) > 0) { do move_to_cell(one_of(safe_no_cues)); return; }
    if (length(safe_any) > 0)     { do move_to_cell(one_of(safe_any));     return; }

    // Fallback: backtrack to known-safe last_cell
    if (last_cell != nil and (last_cell in neigh) and (last_cell != current_cell)) {
        point back_p <- { int(last_cell.grid_x), int(last_cell.grid_y) };
        if (known_safe contains back_p) {
            do move_to_cell(last_cell);
            return;
        }
    }

    do move_patrol_safe_one_step;
}


action move_to_cell_forced (gworld dest) {

    if (!alive) { return; }
    if (current_cell = nil) { return; }
    if (dest = nil) { return; }

    gworld from <- current_cell;

    prev_pos <- location;

    int dx <- int(dest.grid_x) - int(from.grid_x);
    int dy <- int(dest.grid_y) - int(from.grid_y);

    if (dx = 1) { last_move <- "E"; }
    else if (dx = -1) { last_move <- "W"; }
    else if (dy = 1) { last_move <- "S"; }
    else if (dy = -1) { last_move <- "N"; }
    else { last_move <- "none"; }

    last_cell <- from;
    current_cell <- dest;

    do goto target: dest.location;
    location <- dest.location;

    steps <- steps + 1;

    if (debug_player) {
        write "FORCED Player step " + steps + " -> " + location + " | intention=" + current_intention;
    }

    do check_lethal_cell;
    if (alive) { do collect_gold_if_present; }
}


action emergency_move_one_step {

    if (!alive) { return; }
    if (current_cell = nil) { return; }

    list<gworld> neigh <- current_cell.neighbors;
    if (length(neigh) = 0) { return; }

    // 1) Backtrack if possible (preferred)
    if (last_cell != nil and (last_cell in neigh) and (last_cell != current_cell)) {
        point back_p <- { int(last_cell.grid_x), int(last_cell.grid_y) };
        if (known_safe contains back_p) {
            do move_to_cell(last_cell);
            return;
        }
    }

    // 2) Any known-safe neighbor (ignoring forbidden here)
    list<gworld> safe_neigh <- [];
    loop c over: neigh {
        point p <- { int(c.grid_x), int(c.grid_y) };
        if (known_safe contains p and c != current_cell) { safe_neigh <- safe_neigh + [c]; }
    }
    if (length(safe_neigh) > 0) {
        do move_to_cell(one_of(safe_neigh));
        return;
    }

    // 3) Neighbor with zero evidence (safe-ish exploration)
    list<gworld> no_evidence <- [];
    loop c over: neigh {
        point p <- { int(c.grid_x), int(c.grid_y) };
        int pit_cnt <- length(pit_evidence where (each = p));
        int w_cnt   <- length(wumpus_evidence where (each = p));
        if (pit_cnt = 0 and w_cnt = 0 and c != current_cell) { no_evidence <- no_evidence + [c]; }
    }
    if (length(no_evidence) > 0) {
        do move_to_cell(one_of(no_evidence));
        return;
    }

    // 4) LAST RESORT (fix for "stuck on breeze/stench"): forced move to the least-risk neighbor
    int best_score <- 999999;
    list<gworld> best <- [];

    loop c over: neigh {
        if (c = current_cell) { continue; }

        point p <- { int(c.grid_x), int(c.grid_y) };
        int pit_cnt <- length(pit_evidence where (each = p));
        int w_cnt   <- length(wumpus_evidence where (each = p));

        int score <- pit_cnt + w_cnt;

        if (score < best_score) {
            best_score <- score;
            best <- [c];
        } else if (score = best_score) {
            best <- best + [c];
        }
    }

    if (length(best) > 0) {
        do move_to_cell_forced(one_of(best));
    }
}


action execute_current_intention_one_step {

if (!alive) { return; }

// Opportunistic gold collection: if gold is here or adjacent, take it immediately
if (current_cell != nil) {

    if (current_cell.has_gold) {
        do collect_gold_if_present;
        return;
    }

    gworld gold_neighbor <- one_of(current_cell.neighbors where (each.has_gold));
    if (gold_neighbor != nil) {
        do move_to_cell(gold_neighbor);
        return;
    }
}

if (current_intention = I_ESCAPE_PIT) {
    do plan_escape_pit_one_step;
} else if (current_intention = I_ESCAPE_WUMPUS) {
    do plan_escape_wumpus_one_step;
} else if (current_intention = I_GET_GOLD) {
    do move_collect_gold_one_step;
} else {
    do move_patrol_safe_one_step;
}
}

action bdi_cycle_step {

    gworld before_cell <- current_cell;

    do perceive_and_revise_beliefs;
    do update_desires_from_beliefs;
    do select_and_update_intention;
    do execute_current_intention_one_step;

    // If we didn't move (typically because a move was blocked), force a safe move.
    if (alive and before_cell != nil and current_cell = before_cell) {
        do emergency_move_one_step;
    }
}

    

    // One reflex does both: perceive first, then move
// ------------------------------
// BDI bootstrap: initial desire
// ------------------------------
// ------------------------------
// SECTION 7: BDI bootstrap (default desire set)
// ------------------------------
init {
    // patrol exists as fallback; strengths are re-set each tick by update_desires_from_beliefs
    do add_desire(predicate: wants_patrol, strength: 0.4);
    do update_desires_from_beliefs;
}

// ------------------------------
// SECTION 7: Plans per intention (priority handled by desire strengths)
// Each plan: perceive -> revise beliefs -> update desires -> act
// ------------------------------
plan bdi_cycle_patrol intention: wants_patrol {
    if (alive and (not is_tester) and (not world.game_finished)) {
        do bdi_cycle_step;
    }
}

plan bdi_cycle_collect intention: wants_collect_gold {
    if (alive and (not is_tester) and (not world.game_finished)) {
        do bdi_cycle_step;
    }
}

plan bdi_cycle_avoid intention: wants_avoid_wumpus {
    if (alive and (not is_tester) and (not world.game_finished)) {
        do bdi_cycle_step;
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

    // --- END SCREENS (Victory / Game Over) ---
    graphics "end_screen_bg" transparency: 0.45 {
        if (game_finished) {
            float s <- max(grid_width, grid_height) * 20.0;
            draw square(s) at: {grid_width / 2.0, grid_height / 2.0} color: #black border: #black;
        }
    }

    graphics "end_screen_text" {
        if (game_finished) {

            float lx <- grid_width * 0.15;
            float base_y <- grid_height * 0.80;
            float gap <- max(1.0, grid_height * 0.08);

            rgb title_col <- (end_outcome = "VICTORY") ? #chartreuse : #red;

            draw end_outcome at: {lx, base_y} size: 48 color: title_col;

            draw ("Gold: " + string(end_gold_collected) + " / " + string(end_gold_total))
                at: {lx, base_y - 1 * gap} size: 24 color: #white;

            draw ("Steps: " + string(end_steps) + " | Cycle: " + string(end_cycle))
                at: {lx, base_y - 2 * gap} size: 24 color: #white;

            draw ("Final cell: " + string(end_cell) + " | Final intention: " + end_intention)
                at: {lx, base_y - 3 * gap} size: 22 color: #white;

            if (end_outcome = "GAME OVER") {
                draw ("Cause: " + end_reason)
                    at: {lx, base_y - 4 * gap} size: 22 color: #white;
            }

            draw ("Known-safe cells: " + string(end_known_safe) + " | Forbidden: " + string(end_forbidden))
                at: {lx, base_y - 5 * gap} size: 20 color: #white;

            draw ("Evidence (pit / wumpus): " + string(end_pit_evidence) + " / " + string(end_wumpus_evidence))
                at: {lx, base_y - 6 * gap} size: 20 color: #white;

            draw ("Simulation paused. Use 'Reload experiment' to restart.")
                at: {lx, base_y - 7 * gap} size: 18 color: #white;
        }
    }
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

    graphics "end_screen_bg" transparency: 0.45 {
        if (game_finished) {
            float s <- max(grid_width, grid_height) * 20.0;
            draw square(s) at: {grid_width / 2.0, grid_height / 2.0} color: #black border: #black;
        }
    }

    graphics "end_screen_text" {
        if (game_finished) {

            float lx <- grid_width * 0.15;
            float base_y <- grid_height * 0.80;
            float gap <- max(1.0, grid_height * 0.08);

            rgb title_col <- (end_outcome = "VICTORY") ? #chartreuse : #red;

            draw end_outcome at: {lx, base_y} size: 48 color: title_col;

            draw ("Gold: " + string(end_gold_collected) + " / " + string(end_gold_total))
                at: {lx, base_y - 1 * gap} size: 24 color: #white;

            draw ("Steps: " + string(end_steps) + " | Cycle: " + string(end_cycle))
                at: {lx, base_y - 2 * gap} size: 24 color: #white;

            draw ("Final cell: " + string(end_cell) + " | Final intention: " + end_intention)
                at: {lx, base_y - 3 * gap} size: 22 color: #white;

            if (end_outcome = "GAME OVER") {
                draw ("Cause: " + end_reason)
                    at: {lx, base_y - 4 * gap} size: 22 color: #white;
            }

            draw ("Known-safe cells: " + string(end_known_safe) + " | Forbidden: " + string(end_forbidden))
                at: {lx, base_y - 5 * gap} size: 20 color: #white;

            draw ("Evidence (pit / wumpus): " + string(end_pit_evidence) + " / " + string(end_wumpus_evidence))
                at: {lx, base_y - 6 * gap} size: 20 color: #white;

            draw ("Simulation paused. Use 'Reload experiment' to restart.")
                at: {lx, base_y - 7 * gap} size: 18 color: #white;
        }
    }
}

        monitor "Tests executed"          value: tests_executed;
        monitor "Number of failed tests"  value: tests_failed;
        monitor "Player count"            value: length(player);
    }
}
