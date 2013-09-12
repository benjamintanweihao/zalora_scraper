defmodule ZaloraScraper.Scraper do
  defrecord Link, url: ""  
  defrecord Page, name: "", skus: []

  alias HTTPotion.Response

  @user_agent  [ "User-agent": "Elixir benjamintanweihao@gmail.com"]

  def start(url) do
    db_setup
    :tv.start
    crawl([url], 0)
  end

  def db_setup do
    # NOTE: Important to set it to public, because we want our spawned process to add stuff.
    :ets.new(:pages,           [:named_table, :public, {:keypos, Page.__record__(:index, :name)+1}])
    :ets.new(:visited_links,   [:named_table, :public, {:keypos, Link.__record__(:index, :url)+1}])
    :ets.new(:unvisited_links, [:named_table, :public, {:keypos, Link.__record__(:index, :url)+1}])
  end
  
  def get_unvisited_links(count) do
    get_unvisited_links(count, [])
  end

  def get_unvisited_links(0, links), do: links

  def get_unvisited_links(count, links) do
    case :ets.last(:unvisited_links) do
      :"$end_of_table" ->
        get_unvisited_links(0, links)
      url ->
        :ets.delete :unvisited_links, url 
        get_unvisited_links(count-1, [url|links])
    end
  end

  def crawl(urls, depth) do
    urls 
    |> 
    Enum.filter(fn(url) -> Enum.empty?(:ets.lookup(:visited_links, url)) end)
    |>
    Enum.map(fn(url) -> 
              :ets.insert :unvisited_links, Link.new(url: url) 
              url
            end)
    |>
    pmap(fn(url) -> process_page(url, depth) end) 

    # NOTE: Push out 100 links
    get_unvisited_links(1000) 
    |>
    crawl(depth+1)
  end

  def process_page(url, depth) do
    IO.puts "Processing #{url} (#{depth})"
    
    page = try do
      get_page(url)
    rescue 
      error -> 
        # crawl([url], depth)
        # IO.inspect error
        ""
    end

    page_name = page |> extract_page_name
    
    if String.length(page_name)> 0 do
      IO.puts page_name
      skus = page |> extract_skus  
      :ets.insert :pages, Page.new(name: page_name, skus: skus)
    end

    # Here we insert the links that we have not visited yet
    page
    |> 
    extract_links
    |> 
    Enum.filter(fn(x) -> String.starts_with?(x, "/") end)
    |>
    Enum.filter(fn(x) -> Enum.empty?(:ets.lookup(:visited_links, x)) end)
    |>
    Enum.each(fn(x) -> :ets.insert_new :unvisited_links, Link.new(url: "http://www.zalora.sg#{x}") end)
  end

  def extract_links(page) do
    result = %r/<a[^>]* href="([^"]*)"/ |> Regex.scan(page) 
    case is_list(result) do
      true  -> result |> Enum.map(fn [_,x] -> x end)
      false -> []
    end
  end

  def get_page(url) do
    :ets.delete :unvisited_links, url 
    case HTTPotion.get(url, @user_agent, [ timeout: 600000 ]) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        :ets.insert_new :visited_links, Link.new(url: url)
        body

      Response[body: _body, status_code: _status, headers: _headers] ->
        ""
    end
  end 

  def extract_page_name(page) do
    result = %r/.*=\s\"(.*.html).*/ |> Regex.run(page)
    case is_list(result) do 
      true  -> List.last(result)
      false -> "" 
    end
  end

  def extract_skus(page) do
    result = %r/[A-Z]{2}[\d]{3}[A-Z]{2}[\d]{2}[A-Z]{5}/ |> Regex.scan(page)
    case is_list(result) do
      true  -> Enum.uniq(result) |> List.flatten
      false -> :ok
    end
  end

  def pmap(collection, fun) do 
    me = self
    collection
    |>
    Enum.map(fn (elem) ->
      spawn_link fn -> (me <- { self, fun.(elem) }) end
    end) 
    |>
    Enum.map(fn (pid) ->
      receive do 
        { ^pid, result } -> result 
      end
    end) 
  end
end
