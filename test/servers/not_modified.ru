run lambda { |env|
  [304, {'Expires' => "#{Time.now + 604_800}"}, []]
}
