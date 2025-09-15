import java.io.*;

public class ExpandROM {
	public static void main(String[] args) {
		try {
			FileInputStream fis = new FileInputStream(new File(args[0]));
			boolean fixByteOrder = args.length > 2 && Boolean.parseBoolean(args[2]);
			if(fixByteOrder) System.out.println("Fixing byte order");
			int aaa = 0;
			FileOutputStream fos = new FileOutputStream("expanded.bin");
			while(fis.available() > 0) {
				if(fixByteOrder) {
					int i1 = fis.read();
					int i2 = fis.available() > 0 ? fis.read() : 0;
					fos.write(i2);
					fos.write(i1);
					aaa++;
				}else fos.write(fis.read());
				aaa++;
			}
			int targSize = Integer.parseInt(args[1]);
			for(int i = aaa; i < targSize; i++) fos.write(i < 65536 ? 0 : 0xFF);
			fos.close();
			fis.close();
		}catch(Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
