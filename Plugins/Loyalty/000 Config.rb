module LoyaltyConfig

#These two make your Loyalty and Happiness based on the Pokemons nature. I would advise editing the changeHappiness && changeLoyalty to your liking.
NATURE_BASED_LOYALTY = true
NATURE_BASED_HAPPINESS = true




#This just makes it to where instead of manually adding loyalty change calls, calling Happiness will ALWAYS also change Loyalty.
HAPPINESS_CALLS_LOYALTY = true

#This just makes it to where your Pokemons Happiness and Loyalty are taken to account when choosing if to be obedient or not, if you have a very 
#Happy Pokemon, but with no Loyalty, it may not obey, an especially happy Pokemon with normal levels of Loyalty will only disobey rarely.
LOYALTY_BASED_DISOBEDIENCE = true


end 