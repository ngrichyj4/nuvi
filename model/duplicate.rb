class Duplicate
  attr_accessor :id
  class << self 
    def downloaded? file
      @id ||= Redis::List.new('id')
      @id.include? file
    end

    def save! id
      @id << id
    end
  end
end