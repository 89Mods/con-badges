import java.io.*;
import java.util.*;

public class ObjParser {
	private class Vertex {
		public double x,y,z;
		public Vertex(double x, double y, double z) {
			this.x = x;
			this.y = y;
			this.z = z;
		}
		public String toString() {
			return String.format("[%#.3f, %#.3f, %#.3f]", x, y, z);
		}
	}
	
	private static int toFixed(double d) {
		double d2 = Math.abs(d);
		int res = (int)(d2 * 65536.0);
		if(d < 0) {
			res ^= 0xFFFFFFFF;
			res += 1;
		}
		return res;
	}
	
	private static String fixedToDB(int fixed) {
		return String.format("0x%08x", fixed);
	}
	
	private void writeFixed(int fixed, FileOutputStream fos) throws Exception {
		fos.write((fixed >> 0) & 0xFF);
		fos.write((fixed >> 8) & 0xFF);
		fos.write((fixed >> 16) & 0xFF);
		fos.write((fixed >> 24) & 0xFF);
	}
	
	public ObjParser(){}
	public void parse(File in, File out, double objScale, double zOffset) {
		try {
			int totalFaces = 0;
			BufferedReader br = new BufferedReader(new FileReader(in));
			FileOutputStream fos = new FileOutputStream(out);
			List<Vertex> verts = new ArrayList<Vertex>();
			List<Vertex> vertColors = new ArrayList<Vertex>();
			List<Vertex> normals = new ArrayList<Vertex>();
			while(true) {
				String line = br.readLine();
				if(line == null) break;
				if(line.startsWith("v ")) {
					String[] parts = line.substring(2).split(" ");
					verts.add(new Vertex(
						Double.parseDouble(parts[0]) * objScale,
						Double.parseDouble(parts[1]) * objScale,
						Double.parseDouble(parts[2]) * objScale + zOffset
					));
					if(parts.length < 6) vertColors.add(new Vertex(1,1,1));
					else vertColors.add(new Vertex(
						Double.parseDouble(parts[3]),
						Double.parseDouble(parts[4]),
						Double.parseDouble(parts[5])
					));
				}
				if(line.startsWith("vn ")) {
					String[] parts = line.substring(3).split(" ");
					normals.add(new Vertex(
						Double.parseDouble(parts[0]),
						Double.parseDouble(parts[1]),
						Double.parseDouble(parts[2])
					));
				}
				if(line.startsWith("f ")) {
					String[] parts = line.substring(2).split(" ");
					if(parts.length != 3) throw new Exception("ERROR: obj file does not consist only of tris");
					Vertex[] faceVerts = new Vertex[3];
					Vertex[] faceColors = new Vertex[3];
					Vertex[] faceNormals = new Vertex[3];
					for(int i = 0; i < 3; i++) {
						int idx = Integer.parseInt(parts[i].split("/")[0]);
						faceVerts[i] = verts.get(idx - 1);
						faceColors[i] = vertColors.get(idx - 1);
					}
					for(int i = 0; i < 3; i++) {
						int idx = Integer.parseInt(parts[i].split("/")[2]);
						faceNormals[i] = normals.get(idx - 1);
					}
					/*Vertex p1 = new Vertex(faceVerts[1].x - faceVerts[0].x, faceVerts[1].y - faceVerts[0].y, faceVerts[1].z - faceVerts[0].z);
					Vertex p2 = new Vertex(faceVerts[2].x - faceVerts[0].x, faceVerts[2].y - faceVerts[0].y, faceVerts[2].z - faceVerts[0].z);
					Vertex normal = new Vertex(
						p1.y * p2.z - p1.z * p2.y,
						p1.z * p2.x - p1.x * p2.z,
						p1.x * p2.y - p1.y * p2.x
					);*/
					for(int i = 0; i < 3; i++) {
						int f1 = toFixed(faceVerts[i].x);
						int f2 = toFixed(faceVerts[i].y);
						int f3 = toFixed(faceVerts[i].z);
						System.out.print("dd ");
						System.out.print(fixedToDB(f1));
						System.out.print(",");
						System.out.print(fixedToDB(f2));
						System.out.print(",");
						System.out.println(fixedToDB(f3));
						
						writeFixed(f1, fos);
						writeFixed(f2, fos);
						writeFixed(f3, fos);
					}
					for(int i = 0; i < 3; i++) {
						int fn1 = toFixed(faceNormals[i].x);
						int fn2 = toFixed(faceNormals[i].y);
						int fn3 = toFixed(faceNormals[i].z);
						System.out.print("dd ");
						System.out.print(fixedToDB(fn1));
						System.out.print(",");
						System.out.print(fixedToDB(fn2));
						System.out.print(",");
						System.out.println(fixedToDB(fn3));
						writeFixed(fn1, fos);
						writeFixed(fn2, fos);
						writeFixed(fn3, fos);
					}
					
					double red = faceColors[0].x + faceColors[1].x + faceColors[2].x;
					red /= 3;
					double green = faceColors[0].y + faceColors[1].y + faceColors[2].y;
					green /= 3;
					double blue = faceColors[0].z + faceColors[1].z + faceColors[2].z;
					blue /= 3;
					if(red < 0) red = 0;
					if(green < 0) green = 0;
					if(blue < 0) blue = 0;
					if(red > 1) red = 1;
					if(green > 1) green = 1;
					if(blue > 1) blue = 1;
					
					int colI = ((int)(red * 255) << 16) | ((int)(green * 255) << 8) | (int)(blue * 255);
					System.out.println(String.format("dd 0x%06x", colI));
					totalFaces++;
					writeFixed(colI, fos);
				}
			}
			System.out.println(totalFaces + " total faces");
			
			fos.close();
			br.close();
		}catch(Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
	public static void main(String[] args) {
		if(args.length != 2) {
			System.err.println("ObjParser [infile.obj] [outfile.bin]");
			System.exit(1);
		}
		new ObjParser().parse(new File(args[0]), new File(args[1]), 0.37, 0);
	}
}
