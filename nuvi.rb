require './model/aggregate'
news = Aggregate.new 'http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/'
news.fetch_and_store!