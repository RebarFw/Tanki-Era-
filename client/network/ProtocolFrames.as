package era2019.mineload {
 import alternativa.osgi.service.clientlog.ClientLog;
 import scpacker.networking.NetworkService;
 import scpacker.networking.commands.Command;
 import scpacker.networking.commands.Type;
 public class ProtocolFrames {
  public static function parse(input:String,pending:String,service:NetworkService):String {
   var text:String=pending+input;
   var start:int=0;
   while(true) {
    var end:int=text.indexOf('end~',start);
    if(end<0)break;
    var args:Array=text.substring(start,end).split(';');
    var kind:Type=NetworkService.getType(args.shift());
    if(kind==null||kind==Type.UNKNOWN)throw new Error('Что то пошло не так  '+text.substring(start,end).split(';')[0]);
    args.push('');
    try {service.sendRequestToAllListeners(new Command(kind,args,text));}
    catch(error:Error) {
     // A late visual update must not discard later initialization frames or
     // a mine-snapshot receipt in this same TCP read. Model/auth/resource
     // failures retain their original fatal handling.
     if(!(error is TypeError)||['change_spec_tank','change_temperature_tank','enable_effect','disable_effect','kill_tank','die'].indexOf(args[0])<0)throw error;
     ClientLog.write('BattlePacketError',String(args[0])+': '+error.toString()+'\n'+error.getStackTrace());
    }
    start=end+4;
   }
   return text.substring(start);
  }
 }
}
