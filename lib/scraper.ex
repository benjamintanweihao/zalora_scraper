defmodule ZaloraScraper.Scraper do
  alias HTTPotion.Response

  def start(url) do
    HTTPotion.start
    crawl([url])
  end

  def crawl(urls) do
    pmap(urls, fn(u) -> process_page(u) end) 
    |> 
    List.flatten
    |> 
    crawl
  end

  def process_page(url) do
    IO.puts "Processing #{url}"

    url
    |> 
    get_page 
    |> 
    extract_links
    |> 
    Enum.filter(fn(x) -> String.starts_with?(x, "/") end)
    |>
    Enum.map(fn(x) -> "http://www.zalora.sg#{x}" end) 
    |>  
    Enum.shuffle
    |>
    Enum.take 2
  end


  def extract_links(page) do
    %r/<a[^>]* href="([^"]*)"/ 
    |> Regex.scan(page) 
    |> Enum.map(fn [_,x] -> x end)
  end

  def get_page(url) do
    case HTTPotion.get(url) do
      Response[body: body, status_code: status, headers: _headers]
      when status in 200..299 ->
        body

      Response[body: _body, status_code: _status, headers: _headers] ->
        ""
    end
  end 

  def extract_page_name(page) do
    result = %r/.*=\s\"(.*.html).*/ |> Regex.run(page)
    case is_list(result) do 
      true  -> List.last(result)
      false -> :ok
    end
  end

  def extract_skus(page) do
    result = %r/[A-Z]{2}[\d]{3}[A-Z]{2}[\d]{2}[A-Z]{5}/ |> Regex.scan(page)
    case is_list(result) do
      true  -> Enum.uniq |> List.flatten  
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