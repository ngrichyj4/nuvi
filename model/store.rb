class Store
  class << self 
    def save! content, name
      @st ||= Redis::List.new('news_xml')
      @st << content

      puts "[Enqueue] Saved. #{name}".colorize(:green)
    end
  end
end