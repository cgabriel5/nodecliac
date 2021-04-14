!function(t){"use strict";var r=function(){function t(t){return t.replace(/[-[\]{}()*+!<=:?.\/\\^$|#\s,]/g,"\\$&")}var r=function(t){return Object.prototype.toString.call(t).replace(/(\[object |\])/g,"").toLowerCase()};r.is=function(t,r){var e=this(t);return r="|"+r.toLowerCase().trim()+"|",Boolean(-~r.indexOf("|"+e+"|"))},r.isnot=function(t,r){return!this.is(t,r)};var e=function(t){var r=t.constructor__,e=t.methods__,a=t.extend__;a&&(r.prototype=Object.create(a.prototype),r.prototype.constructor=r);var n=r.prototype;for(var o in e)e.hasOwnProperty(o)&&(n[o]=e[o]);return r}({constructor__:function(t,r){if(!(this instanceof e))return new e(t,r);this.controller=t||void 0,this.object=r||{},this.cache={},this.callbacks=[]},methods__:{get:function(t){var e=this,a=e.object;t=t.replace(/^\.+|\.+$/g,"");for(var n=t.split("."),o=0,i=n.length;o<i;o++){var c=n[o],l=(c.match(/^[^\[]+/g)||[""])[0],s=c.match(/\[\d+\]/g)||[];n[o]=[c,l,s]}for(var v=a,o=0,i=n.length;o<i;o++){var c=n[o],l=c[1],s=c[2];if(!v[l]&&!v.hasOwnProperty(l))return!1;if(v,v=v[l],s.length)for(var h=0,g=s.length;h<g;h++){var p=s[h].replace(/^\[|\]$/g,"");if(v,v=v[p],r.isnot(v,"Object|Array"))return!1}}return{val:v}},set:function(t,e,a){var n,o=this,i=o.object,c=o.cache,l=Date.now(),a=a||{},s="update";if(!(n=c[t.trim()])){var v=o.get(t),h=r.is(v,"Object");n=[,,h?v.val:void 0],s=h?"update":"add"}var g=n?n[2]:void 0;c[t]=[l,s,e,a],t=t.replace(/^\.+|\.+$/g,"");for(var p=t.split("."),f=0,u=p.length;f<u;f++){var d=p[f],b=(d.match(/^[^\[]+/g)||[""])[0],m=d.match(/\[\d+\]/g)||[];p[f]=[d,b,m]}for(var y=i,f=0,u=p.length;f<u;f++){var d=p[f],b=d[1],m=d[2];if(f!==u-1||m.length){var w=y[b]?y[b]:m.length?[]:{};y[b]=w,y,y=y[b]}else y[b]=e;if(m.length)for(var j=0,O=m.length;j<O;j++){var _=m[j].replace(/^\[|\]$/g,"");if(j===O-1)if(f===u-1)y[_]=e;else{var w=y[_]?y[_]:{};y[_]=w,y,y=y[_]}else{var w=y[_]?y[_]:[];y[_]=w,y,y=y[_]}}}var x=[t,s,e,g,l,a];o.controller&&o.controller.apply(o,x);for(var $=this.callbacks,f=0,u=$.length;f<u;f++){var k=$[f],S=k[0],C=k[1],I=C.monitorName;S.lastIndex=0,S.test(t)&&C.apply(o,[I].concat(x.slice()))}return i},unset:function(t,e){var a=this,n=a.object,e=(a.cache,e||{}),o=Date.now();t=t.replace(/^\.+|\.+$/g,"");for(var i=t.split("."),c=0,l=i.length;c<l;c++){var s=i[c],v=(s.match(/^[^\[]+/g)||[""])[0],h=s.match(/\[\d+\]/g)||[];i[c]=[s,v,h]}for(var g=n,p=n,c=0,l=i.length;c<l;c++){var s=i[c],v=s[1],h=s[2];if(!p[v]&&!p.hasOwnProperty(v))return!1;if(g=p,p=p[v],h.length)for(var f=0,u=h.length;f<u;f++){var d=h[f].replace(/^\[|\]$/g,"");if(g=p,p=p[d],r.isnot(p,"Object|Array"))return!1}}delete g[v];var b=[t,"delete",void 0,p,o,e];a.controller&&a.controller.apply(a,b);for(var m=this.callbacks,c=0,l=m.length;c<l;c++){var y=m[c],w=y[0],j=y[1],O=j.monitorName;w.lastIndex=0,w.test(t)&&j.apply(a,[O].concat(b.slice()))}},trigger:function(t,e,a){var n,o=this,i=(o.object,o.cache),c=Date.now(),a=a||{};if(!(n=i[t.trim()])){var l=o.get(t);n=[,,r.is(l,"Object")?l.val:void 0]}var s=n?n[2]:void 0;i[t]=[c,"trigger",e,a];var v=[t,"trigger",e||void 0,s,c,a];o.controller&&o.controller.apply(o,v);for(var h=this.callbacks,g=0,p=h.length;g<p;g++){var f=h[g],u=f[0],d=f[1],b=d.monitorName;u.lastIndex=0,u.test(t)&&d.apply(o,[b].concat(v.slice()))}},on:function(e,a){if("string"===r(e))e=new RegExp("^"+t(e)+"$","");else{var n=[],o={global:"g",ignoreCase:"i",multiline:"m",unicode:"u",sticky:"y"};for(var i in o)o.hasOwnProperty(i)&&e[i]&&n.push(o[i]);var c=e.toString(),l=c.lastIndexOf("/");c=c.substring(1,l),e=new RegExp(c,n.join(""))}a.monitorName=e.toString(),this.callbacks.push([e,a])},off:function(e,a){for(var n=this.callbacks,o=!1,i=0,c=n.length;i<c;i++){var l=n[i],s=l[0];l[1];"string"===r(e)&&(e=new RegExp("^"+t(e)+"$","")),s.toString()===e.toString()&&(n.splice(i,1),o=!0)}a&&o&&a.apply(this,[e])},clearCache:function(){this.cache={}}},extend__:!1});return e}(),e=t.app||(t.app={});(e.libs||(e.libs={})).Monitor=r}(window);