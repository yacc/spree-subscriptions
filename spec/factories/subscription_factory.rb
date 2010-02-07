Factory.define :subscription do |s|
  s.start_date "2010-02-01"
  s.end_date "2010-03-01" 
  s.duration 1
  s.interval "month"
  s.state "active"
  s.association :variant, :factory => :variant
  s.association :payment_profile_key, :factory => :variant
  #s.user_id 1068482856
  #s.variant_id 1025786075
  #s.creditcard_id 1066920885
  #s.payment_profile_key nil
end
