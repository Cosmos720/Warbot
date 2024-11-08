///////////////////////////////////////////////////////////////////////////
//
// The code for the red team
// ===========================
//
///////////////////////////////////////////////////////////////////////////

class RedTeam extends Team {
  
  PVector base1, base2;

  // coordinates of the 2 bases, chosen in the rectangle with corners
  // (width/2, 0) and (width, height-100)
  RedTeam() {
    int halfWidth = width/2;
    int halfHeight = (height - 100) / 2;

    // first base
    base1 = new PVector(halfWidth + (int)random(2*(halfWidth/10), 8*(halfWidth/10)), halfHeight - (int)random(2*(halfHeight/10), 8*(halfHeight/10)));
    // second base
    base2 = new PVector(halfWidth + (int)random(2*(halfWidth/10), 8*(halfWidth/10)), halfHeight + (int)random(2*(halfHeight/10), 8*(halfHeight/10)));
  }  
}

interface RedRobot {
  final int INFORM_ABOUT_DESTROYED_BASE = 5;
  final int BECOME_DALEKS = 6;
  final int GO_HOME = 7;
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green bases
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   5.x : Number of harvester to create
//   5.y : Number of rocket launcher to create
//   5.z : Number of explorer to create
//   1.x / 1.y : Coordinate of nearest enemy base
//   1.z = tick de l'enregistrement
///////////////////////////////////////////////////////////////////////////
class RedBase extends Base implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedBase(PVector p, color c, Team t) {
    super(p, c, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the base
  //
  void setup() {
    // creates a new harvester
    newHarvester();
    // 7 more harvesters to create
    brain[5].x = 7;
    brain[5].z = 1;
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    // handle received messages 
    handleMessages();

    // creates new robots depending on energy and the state of brain[5]
    if ((brain[5].x > 0) && (energy >= 1000 + harvesterCost)) {
      // 1st priority = creates harvesters 
      if (newHarvester())
        brain[5].x--;
    } else if ((brain[5].y > 0) && (energy >= 1000 + launcherCost)) {
      // 2nd priority = creates rocket launchers 
      if (newRocketLauncher())
        brain[5].y--;
    } else if ((brain[5].z > 0) && (energy >= 1000 + explorerCost)) {
      // 3rd priority = creates explorers 
      if (newExplorer())
        brain[5].z--;
    } else if (energy > 12000) {
      // if no robot in the pipe and enough energy 
      switch((int)random(3)){
        case 0:
          brain[5].x++;
          break;
        case 1:
          brain[5].y++;
          break;
        case 2:
          brain[5].z++;
          break;
      }
      /*
      if ((int)random(2) == 0)
        // creates a new harvester with 50% chance
        brain[5].x++;
      else if ((int)random(2) == 0)
        // creates a new rocket launcher with 25% chance
        brain[5].y++;
      else
        // creates a new explorer with 25% chance
        brain[5].z++;
      */
    }

    // creates new bullets and fafs if the stock is low and enought energy
    if ((bullets < 10) && (energy > 1000))
      newBullets(50);
    if ((fafs < 10) && (energy > 5000))
      newFafs(10);

    // if ennemy rocket launcher in the area of perception
    Robot bob = (Robot)minDist(perceiveRobots(ennemy));
    if (bob != null) {
      heading = towards(bob);
      // launch a faf if no friend robot on the trajectory...
      if (perceiveRobotsInCone(friend, heading) == null)
        launchFaf(bob);
    }
    // if enemy base known, inform friend rocket launcher about the coordinate of the nearest enemy base
    if (brain[4].z == 1){
      RocketLauncher rocket = (RocketLauncher)oneOf(perceiveRobots(friend, LAUNCHER));
      if (rocket != null){
        informAboutXYTarget(rocket, brain[1]);
      }
    }
  }

  //
  // handleMessage
  // =============
  // > handle messages received since last activation 
  //
  void handleMessages() {
    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      msg = messages.get(i);
      if (msg.type == ASK_FOR_ENERGY) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0]) {
          // gives the requested amount of energy only if at least 1000 units of energy left after
          giveEnergy(msg.alice, msg.args[0]);
        }
      } else if (msg.type == ASK_FOR_BULLETS) {
        // if the message is a request for energy
        if (energy > 1000 + msg.args[0] * bulletCost) {
          // gives the requested amount of bullets only if at least 1000 units of energy left after
          giveBullets(msg.alice, msg.args[0]);
        }
      } else if (msg.type == INFORM_ABOUT_XYTARGET) {
        PVector p = new PVector();
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p)<distance(brain[1]) || brain[4].z==0) {
          brain[1] = p;
          brain[1].z = game.ticks;
          brain[4].z = 1;
        }
      } else if (msg.type == INFORM_ABOUT_DESTROYED_BASE) {
        PVector p = new PVector();
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (brain[1].x == p.x && brain[1].y == p.y){
          brain[1] = new PVector();
          brain[4].z = 0;
        }
      }
    }
    // clear the message queue
    flushMessages();
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green explorers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = exploration | 1 = go back to base)
//   4.y = (0 = no target | 1 = locked target)
//   4.z = (0 = no ennemy base | 1 = ennemy base found)
//   0.x / 0.y = coordinates of the target
//   0.z = type of the target
//   1.x / 1.y = position of the enemy base target
//   1.z = tick de l'enregistrement
///////////////////////////////////////////////////////////////////////////
class RedExplorer extends Explorer implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedExplorer(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    handleMessages();
    // if food to deposit or too few energy
    if (brain[2].z == 0){
      if ((carryingFood > 200) || (energy < 100))
        // time to go back to base
        brain[4].x = 1;

      // depending on the state of the robot
      if (brain[4].x == 1) {
        // go back to base...
        goBackToBase();
      } else {
        // ...or explore randomly
        randomMove(45);
      }

      // tries to localize ennemy bases
      lookForEnnemyBase();
      // inform harvesters about food sources
      driveHarvesters();
      // inform rocket launchers about targets
      driveRocketLaunchers();
      // forget ennemy base after 1000 ticks
      forgetEnnemyBase();

      if (brain[4].z == 1){
        informAboutBase(brain[1]);
      }
    } else { //Dalek behavior
      Robot dalek = folowingOf(perceiveRobots(friend, LAUNCHER));
      if (dalek != null){
        if ((carryingFood > 200) || (energy < 100)){
          Base home = (Base)oneOf(perceiveRobots(friend, BASE));
          if (home != null){
            askForEnergy(home, 1500 - energy);
          } else {
            goHome(dalek);
          }
        }
        if (distance(dalek) >= 3){
          heading = towards(dalek);
          tryToMoveForward();
        }
        driveRocketLaunchers();
      }
    }
    // clear the message queue
    flushMessages();
  }

  //
  // goHome
  // ===================
  // > sends a GO_HOME message to another robot
  //
  // input
  // -----
  // > bob = the id (who) of the receiver
  // > p = the position of the target
  //
  void goHome(Robot bob) {
    // if bob exists and distance less than max range
    if ((bob != null) && (distance(bob) < messageRange)) {
      // build the message...
      float[] args = new float[1];
      args[0] = who;
      Message msg = new Message(GO_HOME, who, bob.who, args);
      // ...and add it to bob's messages queue
      bob.messages.add(msg);
    }
  }

  Robot folowingOf(ArrayList<Robot> agentSet) {
    // check that the list is not null and not of length 0
    if ((agentSet != null) && (agentSet.size() != 0)) {
      for(Robot robot : agentSet){
        if (robot.who == brain[2].z){
          // return the following agent
          return robot;
        }
      }
    }
    // else return null
    return null;
  }

  //
  // setTarget
  // =========
  // > locks a target
  //
  // inputs
  // ------
  // > p = the location of the target
  // > breed = the breed of the target
  //
  void setTarget(PVector p, int breed) {
    brain[0].x = p.x;
    brain[0].y = p.y;
    brain[0].z = breed;
    brain[4].y = 1;
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest base, either to deposit food or to reload energy
  //
  void goBackToBase() {
    // bob is the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one (not all of my bases have been destroyed)
      float dist = distance(bob);

      if (dist <= 2) {
        // if I am next to the base
        if (energy < 500)
          // if my energy is low, I ask for some more
          askForEnergy(bob, 1500 - energy);
        // switch to the exploration state
        brain[4].x = 0;
        // make a half turn
        right(180);
      } else {
        // if still away from the base
        // head towards the base (with some variations)...
        heading = towards(bob) + random(-radians(20), radians(20));
        // ...and try to move forward 
        tryToMoveForward();
      }
    }
  }

  //
  // target
  // ======
  // > checks if a target has been locked
  //
  // output
  // ------
  // true if target locket / false if not
  //
  boolean target() {
    return (brain[4].y == 1);
  }

  //
  // driveHarvesters
  // ===============
  // > tell harvesters if food is localized
  //
  void driveHarvesters() {
    // look for burgers
    Burger zorg = (Burger)oneOf(perceiveBurgers());
    if (zorg != null) {
      // if one is seen, look for a friend harvester
      Harvester harvey = (Harvester)oneOf(perceiveRobots(friend, HARVESTER));
      if (harvey != null)
        // if a harvester is seen, send a message to it with the position of food
        informAboutFood(harvey, zorg.pos);
    }
  }

  //
  // driveRocketLaunchers
  // ====================
  // > tell rocket launchers about potential targets
  //
  void driveRocketLaunchers() {
    // look for an ennemy robot 
    Robot bob = (brain[2].z == 0) ? (Robot)oneOf(perceiveRobots(ennemy)) : (Robot)oneOf(perceiveRobots(ennemy, HARVESTER));
    if (bob != null) {
      // if one is seen, look for a friend rocket launcher
      RocketLauncher rocky = (brain[2].z == 0) ? (RocketLauncher)oneOf(perceiveRobots(friend, LAUNCHER)) : (RocketLauncher)folowingOf(perceiveRobots(friend, LAUNCHER));
      if (rocky != null)
        // if a rocket launcher is seen, send a message with the localized ennemy robot
        informAboutTarget(rocky, bob);
    }
  }

  //
  // lookForEnnemyBase
  // =================
  // > try to localize ennemy bases...
  // > ...and to communicate about this to other friend explorers
  //
  void lookForEnnemyBase() {
    // look for an ennemy base
    Base babe = (Base)oneOf(perceiveRobots(ennemy, BASE));
    if (babe != null) {
      PVector p = new PVector();
      p.x = babe.pos.x;
      p.y = babe.pos.y;
      p.z = game.ticks;
      brain[1] = p;
      //enemy base found
      brain[4].z = 1;
    }
  }

  //
  // forgetEnnemyBase
  // =================
  // > Forget ennemy base after a certain amount of time
  //
  void forgetEnnemyBase() {
    if(brain[4].z == 1 && brain[1].z+1000 <= game.ticks){
      brain[1]=new PVector();
      brain[4].z = 0;
    }
  }

  //
  // becomeDaleks
  // ===================
  // > sends a BECOME_DALEKS message to another robot
  //
  // input
  // -----
  // > bob = the id (who) of the receiver
  // > p = the position of the target
  //
  void becomeDaleks(int id) {
    Robot bob = game.getRobot(id);
    // if bob exists and distance less than max range
    if ((bob != null) && (distance(bob) < messageRange)) {
      // build the message...
      float[] args = new float[1];
      args[0] = who;
      Message msg = new Message(BECOME_DALEKS, who, bob.who, args);
      // ...and add it to bob's messages queue
      bob.messages.add(msg);
    }
  }



  void informAboutBase(PVector babe) {
    Explorer explo = (Explorer)oneOf(perceiveRobots(friend, EXPLORER));
      if (explo != null)
        // if one is seen, send a message with the localized ennemy base
        informAboutXYTarget(explo, babe);
      // look for a friend base
    Base basy = (Base)oneOf(perceiveRobots(friend, BASE));
      if (basy != null){
        // if one is seen, send a message with the localized ennemy base
        informAboutXYTarget(basy, babe);
        brain[1] = new PVector();
      }
  }

  void handleMessages() {
    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized target" message
      if (msg.type == INFORM_ABOUT_XYTARGET) {
        PVector p = new PVector();
        p.x = msg.args[0];
        p.y = msg.args[1];
        brain[1] = p;
        brain[1].z = game.ticks;
        //enemy base found
        brain[4].z = 1;
      } else if (msg.type == INFORM_ABOUT_DESTROYED_BASE) {
        PVector p = new PVector();
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (brain[1].x == p.x && brain[1].y == p.y){
          brain[1] = new PVector();
        }
      } else if (msg.type == BECOME_DALEKS && brain[2].z == 0) {
        brain[2].z = msg.args[0];
        becomeDaleks(msg.alice);
      }
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(360));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green harvesters
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   4.x = (0 = look for food | 1 = go back to base) 
//   4.y = (0 = no food found | 1 = food found)
//   0.x / 0.y = position of the localized food
///////////////////////////////////////////////////////////////////////////
class RedHarvester extends Harvester implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedHarvester(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    // handle messages received
    handleMessages();

    // check for the closest burger
    Burger b = (Burger)minDist(perceiveBurgers());
    if ((b != null) && (distance(b) <= 2))
      // if one is found next to the robot, collect it
      takeFood(b);

    // if food to deposit or too few energy
    if ((carryingFood > 200) || (energy < 100))
      // time to go back to the base
      brain[4].x = 1;

    // if in "go back" state
    if (brain[4].x == 1) {
      // go back to the base
      goBackToBase();

      // if enough energy and food
      if ((energy > 100) && (carryingFood > 100)) {
        // check for closest base
        Base bob = (Base)minDist(myBases);
        if (bob != null) {
          // if there is one and the harvester is in the sphere of perception of the base
          if (distance(bob) < basePerception)
            // plant one burger as a seed to produce new ones
            plantSeed();
        }
      }
    } else
      // if not in the "go back" state, explore and collect food
      goAndEat();
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest friend base
  //
  void goBackToBase() {
    // look for the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one
      float dist = distance(bob);
      if ((dist > basePerception) && (dist < basePerception + 1))
        // if at the limit of perception of the base, drops a wall (if it carries some)
        dropWall();

      if (dist <= 2) {
        // if next to the base, gives the food to the base
        giveFood(bob, carryingFood);
        if (energy < 500)
          // ask for energy if it lacks some
          askForEnergy(bob, 1500 - energy);
        // go back to "explore and collect" mode
        brain[4].x = 0;
        // make a half turn
        right(180);
      } else {
        // if still away from the base
        // head towards the base (with some variations)...
        heading = towards(bob) + random(-radians(20), radians(20));
        // ...and try to move forward
        tryToMoveForward();
      }
    }
  }

  //
  // goAndEat
  // ========
  // > go explore and collect food
  //
  void goAndEat() {
    // look for the closest wall
    Wall wally = (Wall)minDist(perceiveWalls());
    // look for the closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      float dist = distance(bob);
      // if wall seen and not at the limit of perception of the base 
      if ((wally != null) && ((dist < basePerception - 1) || (dist > basePerception + 2)))
        // tries to collect the wall
        takeWall(wally);
    }

    // look for the closest burger
    Burger zorg = (Burger)minDist(perceiveBurgers());
    if (zorg != null) {
      // if there is one
      if (distance(zorg) <= 2)
        // if next to it, collect it
        takeFood(zorg);
      else {
        // if away from the burger, head towards it...
        heading = towards(zorg) + random(-radians(20), radians(20));
        // ...and try to move forward
        tryToMoveForward();
      }
    } else if (brain[4].y == 1) {
      // if no burger seen but food localized (thank's to a message received)
      if (distance(brain[0]) > 2) {
        // head towards localized food...
        heading = towards(brain[0]);
        // ...and try to move forward
        tryToMoveForward();
      } else
        // if the food is reached, clear the corresponding flag
        brain[4].y = 0;
    } else {
      // if no food seen and no food localized, explore randomly
      heading += random(-radians(45), radians(45));
      tryToMoveForward();
    }
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(360));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }

  //
  // handleMessages
  // ==============
  // > handle messages received
  // > identify the closest localized burger
  //
  void handleMessages() {
    float d = width;
    PVector p = new PVector();

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized food" message
      if (msg.type == INFORM_ABOUT_FOOD) {
        // record the position of the burger
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p) < d) {
          // if burger closer than closest burger
          // record the position in the brain
          brain[0].x = p.x;
          brain[0].y = p.y;
          // update the distance of the closest burger
          d = distance(p);
          // update the corresponding flag
          brain[4].y = 1;
        }
      }
    }
    // clear the message queue
    flushMessages();
  }
}

///////////////////////////////////////////////////////////////////////////
//
// The code for the green rocket launchers
//
///////////////////////////////////////////////////////////////////////////
// map of the brain:
//   0.x / 0.y = position of the target
//   0.z = breed of the target
//   1.x / 1.y = position of the enemy base target
//   1.z = (0 = no enemy base targeted | 1 = enemy base targeted)
//   4.x = (0 = look for target | 1 = go back to base) 
//   4.y = (0 = no target | 1 = localized target)
//   4.z = (0 = look for ennemy base | 1 = ennemy base destroyed)
///////////////////////////////////////////////////////////////////////////
class RedRocketLauncher extends RocketLauncher implements RedRobot {
  //
  // constructor
  // ===========
  //
  RedRocketLauncher(PVector pos, color c, ArrayList b, Team t) {
    super(pos, c, b, t);
  }

  //
  // setup
  // =====
  // > called at the creation of the agent
  //
  void setup() {
  }

  //
  // go
  // ==
  // > called at each iteration of the game
  // > defines the behavior of the agent
  //
  void go() {
    handleMessages();
    // if no energy or no bullets
    if ((energy < 100) || (bullets == 0))
      // go back to the base
      brain[4].x = 1;

    if (brain[2].z != 0){
      Explorer explorer = (Explorer)folowingOf(perceiveRobots(friend, EXPLORER));
      if (explorer == null){
        brain[2].z = 0;
      }
    }

    if (brain[4].x == 1) {
      // if in "go back to base" mode
      goBackToBase();
    } else {
      if(brain[1].z == 1 && brain[2].z == 0){
        if(goToTarget(brain[1])){
          // shoot on the target
          Base b = (Base)oneOf(perceiveRobots(ennemy, BASE));
          if(b != null){
            launchBullet(towards(b));
          } else {
            brain[1].z = 0;
            brain[4].z = 1;
            brain[4].x = 1;
          }
        }
      } else {
        Explorer explorer = (Explorer)oneOf(perceiveRobots(friend, EXPLORER));
        if((int)random(100)>=95 && explorer != null && brain[2].z == 0){
          becomeDaleks(explorer);
        }
        if(!target()){
          // try to find a target
          selectTarget();
        }
        if (target() && goToTarget(brain[0])){
          // shoot on the target
          Robot bob = (brain[2].z == 0) ? (Robot)minDist(perceiveRobots(ennemy)) : (Robot)minDist(perceiveRobots(ennemy, HARVESTER));
            
          if(bob != null){
            launchBullet(towards(bob));
          } else {
            brain[4].y = 0;
          }
        } else {
          randomMove(45);
        }
      }
    }
    if (brain[4].z == 1){
      ArrayList<Robot> bob = (ArrayList<Robot>)perceiveRobots(friend);
      if (bob!=null){
        for(Robot r : bob){
          PVector p = new PVector();
          p.x = brain[1].x;
          p.y = brain[1].y;
          informAboutDestroyedBase(r, p);
        }
      }
    }
  }

  Robot folowingOf(ArrayList<Robot> agentSet) {
    // check that the list is not null and not of length 0
    if ((agentSet != null) && (agentSet.size() != 0)) {
      for(Robot robot : agentSet){
        if (robot.who == brain[2].z){
          // return the following agent
          return robot;
        }
      }
    }
    // else return null
    return null;
  }

  //
  // becomeDaleks
  // ===================
  // > sends a BECOME_DALEKS message to another robot
  //
  // input
  // -----
  // > bob = the id (who) of the receiver
  // > p = the position of the target
  //
  void becomeDaleks(Robot bob) {
    // if bob exists and distance less than max range
    if ((bob != null) && (distance(bob) < messageRange)) {
      // build the message...
      float[] args = new float[1];
      args[0] = who;
      Message msg = new Message(BECOME_DALEKS, who, bob.who, args);
      // ...and add it to bob's messages queue
      bob.messages.add(msg);
    }
  }


  boolean goToTarget(PVector t){
    if (distance(t)>detectionRange-3){
      heading = towards(t);
      tryToMoveForward();
      return false;
    }
    return true;
  }

  //
  // selectTarget
  // ============
  // > try to localize a target
  //
  void selectTarget() {
    // look for the closest ennemy robot
    Robot bob;
    if (brain[2].z == 0){
      bob = (Robot)minDist(perceiveRobots(ennemy));
    } else {
      bob = (Robot)minDist(perceiveRobots(ennemy, HARVESTER));
    }
    if (bob != null) {
      // if one found, record the position and breed of the target
      brain[0].x = bob.pos.x;
      brain[0].y = bob.pos.y;
      brain[0].z = bob.breed;
      // locks the target
      brain[4].y = 1;
    } else
      // no target found
      brain[4].y = 0;
  }

  //
  // target
  // ======
  // > checks if a target has been locked
  //
  // output
  // ------
  // > true if target locket / false if not
  //
  boolean target() {
    return (brain[4].y == 1);
  }

  //
  // goBackToBase
  // ============
  // > go back to the closest base
  //
  void goBackToBase() {
    // look for closest base
    Base bob = (Base)minDist(myBases);
    if (bob != null) {
      // if there is one, compute its distance
      float dist = distance(bob);

      if (dist <= 2) {
        // if next to the base
        if (energy < 500)
          // if energy low, ask for some energy
          askForEnergy(bob, 1500 - energy);
        // go back to "exploration" mode
        brain[4].x = 0;
        // make a half turn
        right(180);
      } else {
        // if not next to the base, head towards it... 
        heading = towards(bob) + random(-radians(20), radians(20));
        // ...and try to move forward
        tryToMoveForward();
      }
    }
  }

  //
  // informAboutDestroyedBase
  // ===================
  // > sends a INFORM_ABOUT_DESTROYED_BASE message to another robot
  //
  // input
  // -----
  // > bob = the id (who) of the receiver
  // > p = the position of the target
  //
  void informAboutDestroyedBase(Robot bob, PVector p) {
    // if bob exists and distance less than max range
    if ((bob != null) && (distance(bob) < messageRange)) {
      // build the message...
      float[] args = new float[2];
      args[0] = p.x;
      args[1] = p.y;
      Message msg = new Message(INFORM_ABOUT_DESTROYED_BASE, who, bob.who, args);
      // ...and add it to bob's messages queue
      bob. messages.add(msg);
    }
  }
  
  //
  // handleMessages
  // ==============
  // > handle messages received
  // > identify the closest localized target
  //
  void handleMessages() {
    float d = width;
    PVector p = new PVector();

    Message msg;
    // for all messages
    for (int i=0; i<messages.size(); i++) {
      // get next message
      msg = messages.get(i);
      // if "localized target" message
      if (msg.type == INFORM_ABOUT_TARGET) {
        // record the position of the target
        p.x = msg.args[0];
        p.y = msg.args[1];
        if (distance(p) < d) {
          if (brain[2].z != 0 && msg.args[2] != HARVESTER){
            break;
          }
          // if burger closer than closest burger
          // record the position in the brain
          brain[0].x = p.x;
          brain[0].y = p.y;
          // update the distance of the closest burger
          d = distance(p);
          // update the corresponding flag
          brain[4].y = 1;
        }
      } else if (msg.type == INFORM_ABOUT_XYTARGET && brain[2].z == 0){
        brain[1].x = msg.args[0];
        brain[1].y = msg.args[1];
        brain[1].z = 1;
      } else if (msg.type == BECOME_DALEKS && brain[2].z == 0){
        brain[2].z = msg.args[0];
      } else if (msg.type == GO_HOME && brain[2].z != 0){
        brain[4].x = 1;
      }
    }
    // clear the message queue
    flushMessages();
  }

  //
  // tryToMoveForward
  // ================
  // > try to move forward after having checked that no obstacle is in front
  //
  void tryToMoveForward() {
    // if there is an obstacle ahead, rotate randomly
    if (!freeAhead(speed))
      right(random(360));

    // if there is no obstacle ahead, move forward at full speed
    if (freeAhead(speed))
      forward(speed);
  }
}
