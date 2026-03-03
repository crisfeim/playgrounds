
@val @scope("document")
external body: Dom.element = "body"

@val @scope("document") @return(nullable)
external getElementById: string => option<Dom.element> = "getElementById"
