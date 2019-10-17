//------------------------------------------------------------------------------------------------------
// Smooth page up scroll
//------------------------------------------------------------------------------------------------------

function pageup(e) {
  var uagent = navigator.userAgent.toUpperCase();
  if (uagent.indexOf("MSIE") >=0) { pos = event.y; }
  else { pos = e.pageY; } moveObject(pos);
  }
	
function moveObject(position) {
  move = position / 15;
  point = parseInt(position - move);
  scrollTo(0,point);
  if (point > 0) { setTimeout("moveObject(point)",10); }
  }

//------------------------------------------------------------------------------------------------------
//Change Font Sizes
//------------------------------------------------------------------------------------------------------
var size=1;
function fontsize(size){
	if(size==1){
	document.body.style.fontSize='80%';
	document.body.style.lineHeight='90%';
	}else if(size==2){
	document.body.style.fontSize='100%';
	document.body.style.lineHeight='110%';
	}else if(size==3){
	document.body.style.fontSize='120%';
	document.body.style.lineHeight='130%';
	}
}
