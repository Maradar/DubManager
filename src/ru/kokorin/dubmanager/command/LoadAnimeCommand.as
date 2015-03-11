package ru.kokorin.dubmanager.command {
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.URLVariables;

import mx.logging.ILogger;

import ru.kokorin.astream.AStream;

import ru.kokorin.astream.AStream;
import ru.kokorin.dubmanager.domain.Anime;
import ru.kokorin.dubmanager.event.AnimeEvent;
import ru.kokorin.util.LogUtil;
import ru.kokorin.util.XmlUtil;

public class LoadAnimeCommand {
    public var callback:Function;
    public var aStream:AStream;

    private var animeId:Number;
    private var xmlFile:File;
    private static const LOGGER:ILogger = LogUtil.getLogger(LoadAnimeCommand);


    public function LoadAnimeCommand(aStream:AStream = null, animeId:Number = NaN) {
        this.aStream = aStream;
        this.animeId = animeId;
    }

    public function execute(event:AnimeEvent = null):void {
        if (event && event.anime) {
            animeId = event.anime.id;
        }
        xmlFile = File.applicationStorageDirectory.resolvePath("anime/" + animeId + ".xml");

        if (xmlFile.exists && xmlFile.size > 10) {
            var weekAgo:Date = new Date();
            weekAgo.date -= 7;

            if (xmlFile.modificationDate.time > weekAgo.time &&
                    xmlFile.creationDate.time > weekAgo.time) {
                try {
                    LOGGER.debug("Loading data from file: {0}", xmlFile.url);
                    const fileStream:FileStream = new FileStream();
                    fileStream.open(xmlFile, FileMode.READ);
                    var xmlString:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
                    fileStream.close();

                    xmlString = XmlUtil.replaceXmlNamespace(xmlString);
                    const anime = aStream.fromXML(XML(xmlString)) as Anime;

                    callback(anime);
                    return;
                } catch (error:Error) {
                    LOGGER.warn(error.getStackTrace());
                }
            }
            LOGGER.debug("XML data is possibly obsolete");
        }

        const loader:URLLoader = new URLLoader();
        const request:URLRequest = new URLRequest("http://api.anidb.net:9001/httpapi");
        const variables:URLVariables = new URLVariables();
        variables.client = "dubmanager";
        variables.clientver = 1;
        variables.protover = 1;
        variables.request = "anime";
        variables.aid = animeId;
        request.data = variables;

        loader.addEventListener(Event.COMPLETE, onLoadComplete);
        loader.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadError);

        LOGGER.debug("Loading XML: {0}?{1}", request.url, variables);
        loader.load(request);
    }

    private function onLoadComplete(event:Event):void {
        const loader:URLLoader = event.target as URLLoader;
        LOGGER.info("Load complete: {0} bytes", loader.bytesLoaded);
        var xmlString:String = String(loader.data);

        if (!xmlFile.parent.exists) {
            xmlFile.parent.createDirectory();
        }

        const fileStream:FileStream = new FileStream();
        fileStream.open(xmlFile, FileMode.WRITE);
        fileStream.writeUTFBytes(xmlString);
        fileStream.close();
        LOGGER.info("Data written to file: {0}", xmlFile.url);

        xmlString = XmlUtil.replaceXmlNamespace(xmlString);
        const anime:Anime = aStream.fromXML(XML(xmlString)) as Anime;

        callback(anime);
    }

    private function onLoadError(event:ErrorEvent):void {
        LOGGER.error("Load error: {0}: {1}", event.errorID, event.text);
        callback(new Error(event.text, event.errorID));
    }
}
}