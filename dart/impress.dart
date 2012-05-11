#import('dart:html');

void main()
{
var theElement = document.query("#impress");
for (final x in theElement.queryAll("div"))
{
  x.innerHTML = "YEAHHHHH";
}

}
