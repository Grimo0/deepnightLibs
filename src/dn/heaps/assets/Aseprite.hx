package dn.heaps.assets;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
#end

#if !heaps-aseprite
#error "Requires haxelib heaps-aseprite"
#end

class Aseprite {

	#if !macro
	public static function convertToSLib(fps:Int, aseRes:aseprite.Aseprite) {
		var slib = new dn.heaps.slib.SpriteLib([ aseRes.toTile() ]);

		// Parse all tags
		for(tag in aseRes.tags) {
			// Read and store frames
			var frames = aseRes.getTag(tag.name);
			if( frames.length==0 )
				continue;

			var baseIndex = frames[0].index;
			for(f in frames) {
				final t = f.tile;
				trace("slice "+tag.name+": "+t.ix+","+t.iy);
				slib.sliceCustom(
					tag.name,0, f.index-baseIndex,
					t.ix, t.iy, t.iwidth, t.iheight,
					0,0, t.iwidth, t.iheight
				);
			}

			// Define animation
			var animFrames = [];
			for(f in frames) {
				var animFrameCount = dn.M.round( dn.M.fmax(1, $v{fps} * f.duration/1000) );
				for( i in 0...animFrameCount ) // HACK Spritelib anims are frame-based, which is bad :(
					animFrames.push(f.index-baseIndex);
			}
			slib.__defineAnim(tag.name, animFrames);
		}

		return slib;
	}
	#end


	/**
		Build an anonymous object containing all "tags" names found in given Aseprite file. Example:
		```haxe
		var dict = Aseprite.extractTagsDictionary("assets/myCharacter.aseprite");
		someAnimManager.play( dict.run ); // if the tag name changes, compilation will show an error, which is cool
		trace(dict); // { run:"run", idle:"idle", attackA:"attackA" }
		```
	**/
	macro public static function extractTagsDictionary(asepritePath:String) {
		var pos = Context.currentPos();
		var ase = readAseprite(asepritePath);

		// List all tags
		final magicId = 0x2018;
		var all : Map<String,Bool> = new Map(); // "Map" type avoids duplicates
		for(f in ase.frames) {
			if( !f.chunkTypes.exists(magicId) )
				continue;
			var tags : Array<ase.chunks.TagsChunk> = cast f.chunkTypes.get(magicId);
			for( tc in tags )
			for( t in tc.tags )
				all.set(t.tagName, true);
		}

		// Create "tags" anonymous structure
		var tagFields : Array<ObjectField> = [];
		for( tag in all.keys() )
			tagFields.push({ field: cleanUpIdentifier(tag),  expr: macro $v{tag} });

		// Return anonymous structure
		return { expr:EObjectDecl(tagFields), pos:pos }
	}


	/**
		Build an anonymous object containing all "slices" names found in given Aseprite file. Example:
		```haxe
		var dict = Aseprite.extractSlicesDictionary("assets/myCharacter.aseprite");
		trace(dict); // { mySlice:"mySlice", grass1:"grass1", stoneWall:"stoneWall" }
		```
	**/
	macro public static function extractSlicesDictionary(asepritePath:String) {
		var pos = Context.currentPos();
		var ase = readAseprite(asepritePath);

		// List all slices
		final magicId = 0x2022;
		var all : Map<String,Bool> = new Map(); // "Map" type avoids duplicates
		for(f in ase.frames) {
			if( !f.chunkTypes.exists(magicId) )
				continue;
			var chunk : Array<ase.chunks.SliceChunk> = cast f.chunkTypes.get(magicId);
			for( s in chunk )
				all.set(s.name, true);
		}

		// Create anonymous structure fields
		var fields : Array<ObjectField> = [];
		for( e in all.keys() )
			fields.push({ field: cleanUpIdentifier(e),  expr: macro $v{e} });

		// Return anonymous structure
		return { expr:EObjectDecl(fields), pos:pos }
	}


	#if macro

	/** Cleanup a string to make a valid Haxe identifier **/
	static inline function cleanUpIdentifier(v:String) {
		return ( ~/[^a-z0-9_]/gi ).replace(v, "_");
	}


	/** Parse Aseprite file from path **/
	static function readAseprite(filePath:String) : ase.Ase {
		var pos = Context.currentPos();

		// Check file existence
		if( !sys.FileSystem.exists(filePath) ) {
			filePath = try Context.resolvePath(filePath)
				catch(_) haxe.macro.Context.fatalError('File not found: $filePath', pos);
		}

		// Break cache if file changes
		Context.registerModuleDependency(Context.getLocalModule(), filePath);

		// Parse file
		var bytes = sys.io.File.getBytes(filePath);
		var ase = try ase.Ase.fromBytes(bytes)
			catch(err:Dynamic) Context.fatalError("Failed to read Aseprite file: "+err, pos);
		return ase;
	}

	#end
}