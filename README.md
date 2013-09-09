# Zalora Scraper

###Problem Statement:
Scrape every page on zalora.sg, and return 2 columns in gzipped CSV format, containing the first 20 SKUs displayed on each page and the page name (which has the format shop.pc.X.Y)

# Getting the page source
```
url = "http://www.zalora.sg/Ultimatum-Max-Air-Utility-Backpack-114877.html"
HTTPotion.Response[status_code: 200, body: body] = HTTPotion.get url

%r/[A-Z]{2}[\d]{3}[A-Z]{2}[\d]{2}[A-Z]{5}/ |> Regex.scan(body)
```
#Protocol

###Starting the Process

```
scraper_pid = Process.spawn(__MODULE__, :start, ["http://www.zalora.sg"])
```

###What messages should it receive?

```
receive do

end
```

###When should the crawler stop?


###Get a page

```
def get_page(url) do
  case HTTPotion.get(url) do
   HTTPotion.Response[status_code: 200, body: ^body] ->
     body
   _ -> :ok  
  end
end 
```

###Extract Links
```
def extract_links(page) do
  %r/<a[^>]* href="([^"]*)"/ 
  |> Regex.scan(page) 
  |> Enum.map(fn [_,x] -> x end)
end
```

### IDEA: Extracting the page and extracting the SKU's can be done in separate processes.

###Extract shop.pc.x.y
```
def extract_page_name(page) do
  result = %r/.*=\s\"(.*.html).*/ |> Regex.run(page)
  case is_list(result) do 
  	true  -> List.last(result)
  	false -> :ok
  end
end
```
###Extract SKUs
```
def extract_skus(page) do
  result = %r/[A-Z]{2}[\d]{3}[A-Z]{2}[\d]{2}[A-Z]{5}/ |> Regex.scan(page)
  case is_list(result) do
    true  -> Enum.uniq |> List.flatten  
    false -> :ok
  end
end
```

