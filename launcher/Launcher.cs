using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Xml;

[assembly: AssemblyTitle("Tanki Era")]
[assembly: AssemblyProduct("Tanki Era")]
[assembly: AssemblyCompany("Tanki Era")]
[assembly: AssemblyVersion("2.0.0.0")]

public sealed class Asset {
    public string name { get; set; }
    public string sha { get; set; }
    public long size { get; set; }
    public string type { get; set; }
}
public sealed class Release {
    public string Directory { get; set; }
    public Dictionary<string, string> Hashes { get; set; }
    public string Revision { get; set; }
    public string RuntimeHash { get; set; }
}
public static class EmbeddedRuntime {
    public static string Ensure(string root) {
        using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("TankiEra.runtime.zip")) {
            if (stream == null) throw new InvalidDataException("The bundled game runtime is missing.");
            using (var memory = new MemoryStream()) {
                stream.CopyTo(memory);
                byte[] bytes = memory.ToArray();
                string directory = Path.Combine(root, "bootstrap");
                Directory.CreateDirectory(directory);
                string path = Path.Combine(directory, Updater.Hash(bytes) + ".zip");
                if (!File.Exists(path) || Updater.Hash(File.ReadAllBytes(path)) != Updater.Hash(bytes)) {
                    string temporary = path + "." + Guid.NewGuid().ToString("N") + ".part";
                    File.WriteAllBytes(temporary, bytes);
                    if (File.Exists(path)) File.Delete(path);
                    File.Move(temporary, path);
                }
                return path;
            }
        }
    }
}
public sealed class Updater {
    public const string Repository = "RebarFw/Tanki-Era-";
    public static readonly string[] Names = { "Loader.swf", "Prelauncher.swf", "library.swf", "socket.cfg",
        "StandaloneLoader.swf", "ClanAddon.swf", "communicator-chat.png", "communicator-news.png" };
    public readonly string Root;
    readonly string runtime;
    readonly JavaScriptSerializer json = new JavaScriptSerializer();
    readonly Action<string> status;
    public Func<string, byte[]> Fetch;
    public Updater(string root, string runtimeZip, Action<string> progress) {
        Root = Path.GetFullPath(root); runtime = runtimeZip; status = progress;
        Fetch = Download;
        Directory.CreateDirectory(Root);
    }
    public void Log(string message) {
        File.AppendAllText(Path.Combine(Root, "launcher.log"), DateTime.UtcNow.ToString("s") + " " + message + Environment.NewLine);
    }
    static byte[] Download(string url) {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        var request = (HttpWebRequest)WebRequest.Create(url);
        request.UserAgent = "TankiEraPlayer/2.0";
        request.Accept = "application/vnd.github+json";
        request.Timeout = 20000; request.ReadWriteTimeout = 60000;
        request.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
        using (var response = request.GetResponse())
        using (var stream = response.GetResponseStream())
        using (var output = new MemoryStream()) {
            byte[] buffer = new byte[65536]; int read;
            while ((read = stream.Read(buffer, 0, buffer.Length)) > 0) {
                output.Write(buffer, 0, read);
                if (output.Length > 100 * 1024 * 1024) throw new InvalidDataException("Download exceeds the supported asset size.");
            }
            return output.ToArray();
        }
    }
    public static string Hash(byte[] bytes) {
        using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant();
    }
    public static string BlobHash(byte[] bytes) {
        using (var hash = SHA1.Create()) {
            byte[] header = Encoding.ASCII.GetBytes("blob " + bytes.Length + "\0");
            hash.TransformBlock(header, 0, header.Length, header, 0);
            hash.TransformFinalBlock(bytes, 0, bytes.Length);
            return BitConverter.ToString(hash.Hash).Replace("-", "").ToLowerInvariant();
        }
    }
    static void WriteText(string path, string text) { File.WriteAllText(path, text, new UTF8Encoding(false)); }
    public static void ValidateAsset(Asset asset, byte[] bytes) {
        if (bytes.LongLength != asset.size || BlobHash(bytes) != asset.sha)
            throw new InvalidDataException("Incomplete or damaged download: " + asset.name);
        if (asset.name.EndsWith(".swf") && (bytes.Length < 8 ||
            !(bytes[0] == 'F' || bytes[0] == 'C' || bytes[0] == 'Z') || bytes[1] != 'W' || bytes[2] != 'S'))
            throw new InvalidDataException("Invalid Flash file: " + asset.name);
    }
    public static Dictionary<string, object> NormalizeConfig(byte[] bytes) {
        var cfg = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(Encoding.UTF8.GetString(bytes));
        if (cfg == null || !cfg.ContainsKey("ip") || !cfg.ContainsKey("port") || !cfg.ContainsKey("resources"))
            throw new InvalidDataException("socket.cfg must contain ip, port and resources.");
        string host = Convert.ToString(cfg["ip"]); int port;
        if (Uri.CheckHostName(host) == UriHostNameType.Unknown || host == "localhost" || host == "0.0.0.0" || host.StartsWith("127."))
            throw new InvalidDataException("socket.cfg needs the host's public IP or domain.");
        if (!Int32.TryParse(Convert.ToString(cfg["port"]), out port) || port < 1 || port > 65535)
            throw new InvalidDataException("Invalid game port in socket.cfg.");
        Uri resources;
        if (!Uri.TryCreate(Convert.ToString(cfg["resources"]), UriKind.Absolute, out resources) ||
            (resources.Scheme != "https" && resources.Scheme != "http") || resources.IsLoopback || resources.UserInfo.Length > 0)
            throw new InvalidDataException("Invalid resources URL in socket.cfg.");
        // Always execute the verified files from this complete release, never mutable remote SWF URLs.
        return new Dictionary<string, object> { {"ip", host}, {"port", port}, {"resources", resources.AbsoluteUri.TrimEnd('/')},
            {"loader", "Loader.swf"}, {"library", "app:/library.swf"} };
    }
    public Release Current() {
        try {
            var release = json.Deserialize<Release>(File.ReadAllText(Path.Combine(Root, "current.json")));
            if (release == null || !Regex.IsMatch(release.Directory ?? "", "^[a-f0-9]{64}$") || release.Hashes == null || release.Hashes.Count < 8) return null;
            string directory = Path.Combine(Root, "releases", release.Directory);
            foreach (var item in release.Hashes) {
                string path = Path.GetFullPath(Path.Combine(directory, item.Key));
                if (!path.StartsWith(directory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) ||
                    !File.Exists(path) || Hash(File.ReadAllBytes(path)) != item.Value) return null;
            }
            foreach (string name in Names.Concat(new[] { "Tanki Era.exe", "Adobe AIR/Versions/1.0/Adobe AIR.dll", "META-INF/AIR/application.xml" }))
                if (!release.Hashes.ContainsKey(name)) return null;
            return release;
        } catch { return null; }
    }
    public string Prepare() {
        var previous = Current();
        try { return PrepareOnline(); }
        catch (Exception error) {
            Log("Update failed: " + error.Message);
            if (previous == null) throw;
            status("Starting the saved game version...");
            Log("Using verified cached release " + previous.Directory);
            return Path.Combine(Root, "releases", previous.Directory);
        }
    }
    public string PrepareOnline() {
        status("Connecting to Tanki Era...");
        var commit = json.Deserialize<Dictionary<string, object>>(Encoding.UTF8.GetString(Fetch(
            "https://api.github.com/repos/" + Repository + "/commits/main")));
        string revision = Convert.ToString(commit["sha"]);
        if (!Regex.IsMatch(revision, "^[a-f0-9]{40}$")) throw new InvalidDataException("Invalid GitHub revision.");
        string runtimeHash = Hash(File.ReadAllBytes(runtime));
        var current = Current();
        if (current != null && current.Revision == revision && current.RuntimeHash == runtimeHash) {
            Log("Already current: " + revision + "; no assets downloaded.");
            return Path.Combine(Root, "releases", current.Directory);
        }
        var all = json.Deserialize<Asset[]>(Encoding.UTF8.GetString(Fetch(
            "https://api.github.com/repos/" + Repository + "/contents/assets?ref=" + revision)));
        var selected = new List<Asset>();
        foreach (string name in Names) {
            var matches = all.Where(a => a.name == name).ToArray();
            if (matches.Length != 1 || matches[0].type != "file" || !Regex.IsMatch(matches[0].sha ?? "", "^[a-f0-9]{40}$") ||
                matches[0].size < 1 || matches[0].size > 100 * 1024 * 1024)
                throw new InvalidDataException("Missing or invalid GitHub asset: " + name);
            selected.Add(matches[0]);
        }
        string version = Hash(Encoding.UTF8.GetBytes("launcher-v2:" + runtimeHash + ":" +
            String.Join(":", selected.Select(a => a.name + ":" + a.sha))));
        if (current != null && current.Directory == version) {
            current.Revision = revision;
            current.RuntimeHash = runtimeHash;
            SaveCurrent(current);
            Log("Already current: " + revision + "; no assets downloaded.");
            return Path.Combine(Root, "releases", version);
        }
        string blobs = Path.Combine(Root, "blobs"); Directory.CreateDirectory(blobs);
        var data = new Dictionary<string, byte[]>();
        foreach (Asset asset in selected) {
            string blob = Path.Combine(blobs, asset.sha);
            byte[] bytes = File.Exists(blob) ? File.ReadAllBytes(blob) : null;
            if (bytes == null || bytes.LongLength != asset.size || BlobHash(bytes) != asset.sha) {
                status("Downloading game updates...");
                bytes = Fetch("https://raw.githubusercontent.com/" + Repository + "/" + revision + "/assets/" + asset.name);
                ValidateAsset(asset, bytes);
                File.WriteAllBytes(blob + ".part", bytes);
                if (File.Exists(blob)) File.Delete(blob);
                File.Move(blob + ".part", blob);
                Log("Downloaded " + asset.name + " (" + bytes.Length + " bytes)");
            }
            ValidateAsset(asset, bytes); data.Add(asset.name, bytes);
        }
        var config = NormalizeConfig(data["socket.cfg"]);
        string releases = Path.Combine(Root, "releases"); Directory.CreateDirectory(releases);
        string stage = Path.Combine(releases, ".staging-" + Guid.NewGuid().ToString("N"));
        try {
            ZipFile.ExtractToDirectory(runtime, stage);
            foreach (string name in Names) File.WriteAllBytes(Path.Combine(stage, name), data[name]);
            WriteText(Path.Combine(stage, "socket.cfg"), json.Serialize(config));
            foreach (string relative in new[] { "application.xml", "META-INF/AIR/application.xml" }) {
                string path = Path.Combine(stage, relative);
                var doc = new XmlDocument(); doc.Load(path);
                var ns = new XmlNamespaceManager(doc.NameTable); ns.AddNamespace("a", doc.DocumentElement.NamespaceURI);
                doc.SelectSingleNode("/a:application/a:initialWindow/a:content", ns).InnerText =
                    "StandaloneLoader.swf?resources=" + Uri.EscapeDataString(Convert.ToString(config["resources"]) + "/resource") +
                    "&prelauncher=Prelauncher.swf&locale=en&library=library.swf&lang=en&swf=Loader.swf&socket=socket.cfg";
                doc.SelectSingleNode("/a:application/a:filename", ns).InnerText = "Tanki Era";
                doc.SelectSingleNode("/a:application/a:name", ns).InnerText = "Tanki Era";
                doc.SelectSingleNode("/a:application/a:initialWindow/a:title", ns).InnerText = "Tanki Era";
                using (var writer = XmlWriter.Create(path, new XmlWriterSettings { Encoding = new UTF8Encoding(false), Indent = true })) doc.Save(writer);
            }
            var release = new Release { Directory = version, Hashes = new Dictionary<string, string>(), Revision = revision, RuntimeHash = runtimeHash };
            foreach (string file in Directory.GetFiles(stage, "*", SearchOption.AllDirectories))
                release.Hashes.Add(file.Substring(stage.Length + 1).Replace('\\', '/'), Hash(File.ReadAllBytes(file)));
            string destination = Path.Combine(releases, version);
            // Never overwrite files belonging to a running client; each release is immutable.
            if (Directory.Exists(destination)) Directory.Move(destination, Path.Combine(releases, ".damaged-" + Guid.NewGuid().ToString("N")));
            Directory.Move(stage, destination);
            SaveCurrent(release);
            Log("Prepared " + revision + " as " + version);
            return destination;
        } finally {
            string allowed = Path.GetFullPath(releases) + Path.DirectorySeparatorChar;
            if (!Path.GetFullPath(stage).StartsWith(allowed, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("Invalid update staging directory.");
            if (Directory.Exists(stage)) Directory.Delete(stage, true);
        }
    }
    void SaveCurrent(Release release) {
        string pointer = Path.Combine(Root, "current.json");
        WriteText(pointer + ".new", json.Serialize(release));
        if (File.Exists(pointer)) File.Replace(pointer + ".new", pointer, null); else File.Move(pointer + ".new", pointer);
    }
}

public sealed class LauncherWindow : Form {
    readonly Label label = new Label();
    readonly string root;
    public LauncherWindow(string cache) {
        root = cache; Text = "Tanki Era"; ClientSize = new Size(390, 110);
        BackColor = Color.FromArgb(15, 21, 28); ForeColor = Color.FromArgb(226, 239, 248);
        Font = new Font("Segoe UI", 10);
        try { Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        label.SetBounds(24, 20, 350, 32); label.Text = "Starting Tanki Era..."; Controls.Add(label);
        var bar = new ProgressBar { Style = ProgressBarStyle.Marquee }; bar.SetBounds(24, 65, 342, 14); Controls.Add(bar);
        Shown += async delegate {
            try {
                var updater = new Updater(root, EmbeddedRuntime.Ensure(root),
                    s => { if (!IsDisposed) BeginInvoke((Action)(() => label.Text = s)); });
                string game = await Task.Run(() => updater.Prepare());
                label.Text = "Checking the game server...";
                string connection = await ConnectionCheck.Run(game);
                updater.Log(connection);
                if (connection.Contains("FAILED") && MessageBox.Show(connection +
                    "\n\nThe game files are ready, but a server connection failed. The host must keep the server running." +
                    "\nSend the host launcher.log. Re-downloading the game will not open a blocked port." +
                    "\n\nTry opening the game anyway?", "Tanki Era connection check",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) { Close(); return; }
                Process.Start(new ProcessStartInfo(Path.Combine(game, "Tanki Era.exe")) { WorkingDirectory = game, UseShellExecute = false });
                Close();
            } catch (Exception ex) {
                MessageBox.Show("Tanki Era could not start. Check your internet connection and try again.\n\n" + ex.Message +
                    "\n\nDetails: " + Path.Combine(root, "launcher.log"), "Tanki Era", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Environment.ExitCode = 1; Close();
            }
        };
    }
    [STAThread] public static int Main(string[] args) {
        string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TankiEraPlayer");
        bool prepareOnly = args.Contains("--prepare-only");
        int index = Array.IndexOf(args, "--cache-dir");
        if (index >= 0 && index + 1 < args.Length) root = Path.GetFullPath(args[index + 1]);
        using (var mutex = new Mutex(false, "Local\\TankiEraUpdater-" + Updater.Hash(Encoding.UTF8.GetBytes(root.ToLowerInvariant())).Substring(0, 20))) {
            bool locked;
            try { locked = mutex.WaitOne(0); } catch (AbandonedMutexException) { locked = true; }
            if (!locked) return 2;
            try {
                if (prepareOnly) {
                    try {
                        var updater = new Updater(root, EmbeddedRuntime.Ensure(root), s => { });
                        updater.PrepareOnline(); return 0;
                    } catch (Exception e) { Directory.CreateDirectory(root); File.AppendAllText(Path.Combine(root, "launcher.log"), e.ToString()); return 1; }
                }
                Application.EnableVisualStyles(); Application.Run(new LauncherWindow(root)); return Environment.ExitCode;
            } finally { mutex.ReleaseMutex(); }
        }
    }
}

public static class ConnectionCheck {
    public static async Task<string> Probe(string host, int port, string name) {
        try {
            using (var socket = new TcpClient()) {
                var connect = socket.ConnectAsync(host, port);
                if (await Task.WhenAny(connect, Task.Delay(5000)) != connect)
                    return "FAILED " + name + " (" + host + ":" + port + "): timed out";
                await connect;
                return "OK " + name + " (" + host + ":" + port + ")";
            }
        } catch (Exception error) { return "FAILED " + name + " (" + host + ":" + port + "): " + error.Message; }
    }
    public static async Task<string> Run(string game) {
        var config = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(Path.Combine(game, "socket.cfg")));
        var resource = new Uri(Convert.ToString(config["resources"]));
        string host = Convert.ToString(config["ip"]);
        var results = await Task.WhenAll(Probe(host, Convert.ToInt32(config["port"]), "game"),
            Probe(host, 843, "Flash policy"), Probe(resource.Host, resource.Port, "resources"));
        return String.Join(Environment.NewLine, results);
    }
}
