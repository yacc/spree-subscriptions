Factory.define :creditcard_withattr, :class => Creditcard do |f|
  f.verification_value 123
  f.month 12
  f.year 2013
  f.number "4111111111111111"
  #f.association :checkout
end
