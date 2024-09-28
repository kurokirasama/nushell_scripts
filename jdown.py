#!/usr/bin/python3

#Jdownloader wrapper V2.0
#necessary 
#pip3 install myjdapi

def main():   
   import myjdapi, json
   from sys import exit

   import argparse
   parser = argparse.ArgumentParser()

   parser.add_argument("-b", "--dev2", dest = "dev2", default = "0", help="dev2 jdown")

   args = parser.parse_args()

   if args.ubb == "0":
      dev = "dev1"
   else :
      dev = "dev2"
   
   #jdownloader instance
   jd=myjdapi.Myjdapi()
   
   jd.connect("user@gmail.com","password")
   
   jd.update_devices()
   
   try:
      device=jd.get_device("JDownloader@" + dev) 
   except myjdapi.exception.MYJDDeviceNotFoundException:
      print(json.dumps({"message":"device not found"}));
      exit() 
   
   #downloads
   full_query = device.downloads.query_packages([{
                   "bytesLoaded" : True,
                   "bytesTotal" : True,
                   "comment" : False,
                   "enabled" : True,
                   "eta" : True,
                   "priority" : False,
                   "finished" : True,
                   "running" : True,
                   "speed" : True,
                   "status" : True,
                   "childCount" : True,
                   "hosts" : True,
                   "saveTo" : False,
                   "maxResults" : -1,
                   "startAt" : 0,
                   "statusIconKey" : False,
                   "uuid" : True,
               }])
   
   if len(full_query) == 0 :
      print(json.dumps({"message":"No downloads found!"}));
      exit()
   
   #parsing
   downloads = []
   for download in full_query:
      download_info = {
        "uuid": download["uuid"],
        "name": download["name"],
        "hosts": download["hosts"][0] if "hosts" in download and len(download["hosts"]) > 0 else "",
        "childCount": download.get("childCount", ""),
        "eta": download.get("eta", ""),
        "speed": download.get("speed") / (2**20) if "speed" in download else "",
        "bytesLoaded": str(download.get("bytesLoaded", "") / 1000000) if "bytesLoaded" in download and download["bytesLoaded"] is not None else "",
        "bytesTotal": str(download.get("bytesTotal", "") / 1000000) if "bytesTotal" in download and download["bytesTotal"] is not None else "",
      }
   
   downloads.append(download_info)

   # print the final JSON structure
   print(json.dumps(downloads))

if __name__ == '__main__':
   main()