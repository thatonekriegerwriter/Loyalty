    # Changing
module Gamedata


  class Trainer
      def to_trainer
      # Determine trainer's name
      tr_name = self.name
      Settings::RIVAL_NAMES.each do |rival|
        next if rival[0] != @trainer_type || !$game_variables[rival[1]].is_a?(String)
        tr_name = $game_variables[rival[1]]
        break
      end
      # Create trainer object
      trainer = NPCTrainer.new(tr_name, @trainer_type)
      trainer.id        = $player.make_foreign_ID
      trainer.items     = @items.clone
      trainer.lose_text = self.lose_text
      # Create each Pokémon owned by the trainer
      @pokemon.each do |pkmn_data|
        species = GameData::Species.get(pkmn_data[:species]).species
        pkmn = Pokemon.new(species, pkmn_data[:level], trainer, false)
        trainer.party.push(pkmn)
        # Set Pokémon's properties if defined
        if pkmn_data[:form]
          pkmn.forced_form = pkmn_data[:form] if MultipleForms.hasFunction?(species, "getForm")
          pkmn.form_simple = pkmn_data[:form]
        end
        pkmn.item = pkmn_data[:item]
        if pkmn_data[:moves] && pkmn_data[:moves].length > 0
          pkmn_data[:moves].each { |move| pkmn.learn_move(move) }
        else
          pkmn.reset_moves
        end
        pkmn.ability_index = pkmn_data[:ability_index] || 0
        pkmn.ability = pkmn_data[:ability]
        pkmn.gender = pkmn_data[:gender] || ((trainer.male?) ? 0 : 1)
        pkmn.shiny = (pkmn_data[:shininess]) ? true : false
        pkmn.super_shiny = (pkmn_data[:super_shininess]) ? true : false
        if pkmn_data[:nature]
          pkmn.nature = pkmn_data[:nature]
        else   # Make the nature random but consistent for the same species used by the same trainer type
          species_num = GameData::Species.keys.index(species) || 1
          tr_type_num = GameData::TrainerType.keys.index(@trainer_type) || 1
          idx = (species_num + tr_type_num) % GameData::Nature.count
          pkmn.nature = GameData::Nature.get(GameData::Nature.keys[idx]).id
        end
        GameData::Stat.each_main do |s|
          if pkmn_data[:iv]
            pkmn.iv[s.id] = pkmn_data[:iv][s.id]
          else
            pkmn.iv[s.id] = [pkmn_data[:level] / 2, Pokemon::IV_STAT_LIMIT].min
          end
          if pkmn_data[:ev]
            pkmn.ev[s.id] = pkmn_data[:ev][s.id]
          else
            pkmn.ev[s.id] = [pkmn_data[:level] * 3 / 2, Pokemon::EV_LIMIT / 6].min
          end
        end
        pkmn.happiness = pkmn_data[:happiness] if pkmn_data[:happiness]
		    pkmn.loyalty = pkmn_data[:loyalty] if pkmn_data[:loyalty]																			
        pkmn.name = pkmn_data[:name] if pkmn_data[:name] && !pkmn_data[:name].empty?
        if pkmn_data[:shadowness]
          pkmn.makeShadow
          pkmn.update_shadow_moves(true)
          pkmn.shiny = false
        end
        pkmn.poke_ball = pkmn_data[:poke_ball] if pkmn_data[:poke_ball]
        pkmn.calc_stats
      end
      return trainer
    end
  end
end

class Battle::Battler
  def loyalty;         return @pokemon ? @pokemon.loyalty : 0;       end
  
  
   def pbObedienceCheck?(choice)
    return true if usingMultiTurnAttack?
    return true if choice[0]!=:UseMove
    return true if !@battle.internalBattle
    return true if !@battle.pbOwnedByPlayer?(@index)
    disobedient = false
    # Pokémon may be disobedient; calculate if it is
    badgeLevel = 10 * (@battle.pbPlayer.badge_count + 1)
    r = @battle.pbRandom(256)
    badgeLevel = GameData::GrowthRate.max_level if @battle.pbPlayer.badge_count >= 8
    if @pokemon.foreign?(@battle.pbPlayer) && @level>badgeLevel
      a = ((@level+badgeLevel)*@battle.pbRandom(256)/256).floor
      disobedient |= (a>=badgeLevel)
    end
    if LoyaltyConfig::LOYALTY_BASED_DISOBEDIENCE == true
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 149 && @pokemon.loyalty == 0 && r <= 50
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 149 && @pokemon.loyalty <= 49 && r <= 25
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 149 && @pokemon.loyalty <= 70 && r <= 20
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 199 && @pokemon.loyalty == 0 && r <= 45
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 199 && @pokemon.loyalty <= 49 && r <= 25
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 199 && @pokemon.loyalty <= 70 && r <= 15
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 249 && @pokemon.loyalty == 0 && r <= 40
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 249 && @pokemon.loyalty <= 49 && r <= 25
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 249 && @pokemon.loyalty <= 70 && r <= 10
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 250 && @pokemon.loyalty == 0 && r <= 35
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 250 && @pokemon.loyalty <= 49 && r <= 25
    return pbDisobey(choice, badgeLevel) if @pokemon.happiness >= 250 && @pokemon.loyalty <= 70 && r <= 5
    return pbDisobey(choice, badgeLevel) if @pokemon.loyalty == 0 && rand(255)<= 75
    return pbDisobey(choice, badgeLevel) if @pokemon.loyalty <= 49 && rand(255)<= 50
    return pbDisobey(choice, badgeLevel) if @pokemon.loyalty <= 74 && rand(255)<= 25
	end
#END EDIT
    disobedient |= !pbHyperModeObedience(choice[2])
    return true if !disobedient
    # Pokémon is disobedient; make it do something else
#    return pbDisobey(choice,badgeLevel)
  end
  
end

class PokemonGlobalMetadata
  attr_accessor :loyaltySteps

alias :_old_loyaltysteps_initialize :initialize
  def initialize
    @loyaltySteps       = 0
  _old_loyaltysteps_initialize
end
end

class Pokemon
  attr_accessor :loyalty
  
  alias :_old_loyalty_initialize :initialize
  def initialize(species, level, owner = $player, withMoves = true, recheck_form = true)
    @loyalty          = 70 
	_old_loyalty_initialize(species, level, owner = $player, withMoves = true, recheck_form = true)
  end
  # Changes the happiness of this Pokémon depending on what happened to change it.
  # @param method [String] the happiness changing method (e.g. 'walking')
  def changeLoyalty(method)
    gain = 0
    bonus = 0
    pkmn = self
	if @loyalty.nil?
	@loyalty = 0
	end
	base = 0
     base = 0 if pkmn.nature ==   :LOVING
     base = 0 if pkmn.nature ==   :HATEFUL
     base = 30 if pkmn.nature ==   :QUIRKY
     base = 0 if pkmn.nature ==   :CAREFUL
     base = -5 if pkmn.nature ==   :SASSY
     base = 0 if pkmn.nature ==   :GENTLE
     base = 0 if pkmn.nature ==   :CALM
     base = 50 if pkmn.nature ==   :RASH
     base = 0 if pkmn.nature ==   :BASHFUL
     base = 0 if pkmn.nature ==   :QUIET
     base = 0 if pkmn.nature ==   :MILD
     base = 0 if pkmn.nature ==   :MODEST
     base = 0 if pkmn.nature ==   :NAIVE
     base = 0 if pkmn.nature ==   :JOLLY
     base = -10 if pkmn.nature ==   :SERIOUS
     base = 75 if pkmn.nature ==   :HASTY
     base = 0 if pkmn.nature ==   :TIMID
     base = 0 if pkmn.nature ==   :LAX
     base = 0 if pkmn.nature ==   :IMPISH
     base = 0 if pkmn.nature ==   :RELAXED
     base = 0 if pkmn.nature ==   :DOCILE
     base = 75 if pkmn.nature ==   :BOLD
     base = 5 if pkmn.nature ==   :NAUGHTY
     base = 10 if pkmn.nature ==   :ADAMANT
     base = 100 if pkmn.nature ==   :BRAVE
     base = 0 if pkmn.nature ==   :LONELY
     base = 70 if pkmn.nature ==   :HARDY
    loyalty_range = @loyalty / 100
if pkmn.nature ==   :HARDY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :LONELY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :BRAVE
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :ADAMANT
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :NAUGHTY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :BOLD
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :DOCILE
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :RELAXED
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :IMPISH
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :LAX
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :TIMID
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :HASTY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :SERIOUS
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :JOLLY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :NAIVE
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :MODEST
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :MILD
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :QUIET
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :BASHFUL
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :RASH
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :CALM
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :GENTLE
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :SASSY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :CAREFUL
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :QUIRKY
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [5, 3, 2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :HATEFUL
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
elsif pkmn.nature ==   :LOVING
      case method
      when "walking"
        gain = [1, 1, 1][loyalty_range]
      when "levelup"
        gain = [5, 4, 3][loyalty_range]
      when "groom"
        gain = [10, 10, 4][loyalty_range]
      when "evberry"
        gain = [10, 5, 2][loyalty_range]
      when "vitamin"
        gain = [5, 3, 2][loyalty_range]
      when "wing"
        gain = [3, 2, 1][loyalty_range]
      when "machine", "battleitem"
        gain = [1, 1, 0][loyalty_range]
      when "faint"
        gain = [-20, -20, -30][loyalty_range]
      when "faintbad"   # Fainted against an opponent that is 30+ levels higher
        gain = [-30, -40, -60][loyalty_range]
      when "powder"
        gain = [-15, -15, -10][loyalty_range]
      when "energyroot"
        gain = [-1, -1, -1][loyalty_range]
      when "revivalherb"
        gain = [-15, -15, -20][loyalty_range]
      when "damaged"
        gain = [-5, -3, -2][loyalty_range]
      when "neglected"
        gain = [-1, -1, -1][loyalty_range]
      when "hungry"
        gain = [-1, -1, -1][loyalty_range]
      when "thirsty"
        gain = [-1, -1, -1][loyalty_range]
      when "tired"
        gain = [-1, -1, -1][loyalty_range]
      when "youareeatingme"
        gain = [-255, -255, -255][loyalty_range]
      when "didDamage"
        gain = [10, 10, 10][loyalty_range]
      when "TrainerPassedOut"
        gain = [10, 10, 10][loyalty_range]
      when "FollowerPkmn"
        gain = [10, 10, 10][loyalty_range]
else
        raise _INTL("Unknown happiness-changing method: {1}", method.to_s)
    end
end
	
    gain=0 if gain.nil?
	pkmn.loyalty = 100 if @loyalty.nil?
    bonus=0 if bonus.nil?
    @loyalty = (@loyalty + gain + base + bonus).clamp(0, 255)
  end
  
  
end