import Layout from "./components/Layout";
import { PageErrorBoundary } from "./components/ui";
import { usePath } from "./router";
import ApplyPage from "./pages/site/ApplyPage";
import ContactPage from "./pages/site/ContactPage";
import DownloadPage from "./pages/site/DownloadPage";
import DriverPage from "./pages/site/DriverPage";
import HomePage from "./pages/site/HomePage";
import { AboutPage, HowItWorksPage, NotFoundPage, SafetyPage } from "./pages/site/InfoPages";
import StatusPage from "./pages/site/StatusPage";

const routes = {
  "/": HomePage,
  "/download": DownloadPage,
  "/driver": DriverPage,
  "/driver/apply": ApplyPage,
  "/driver/status": StatusPage,
  "/how-it-works": HowItWorksPage,
  "/safety": SafetyPage,
  "/about": AboutPage,
  "/contact": ContactPage,
};

export default function App() {
  const path = usePath();
  const Page = routes[path] || NotFoundPage;
  // Keyed by path so each visit starts the page fresh (e.g. the apply flow)
  // and the new page plays its entrance.
  return (
    <Layout>
      <div className="page" key={path}>
        <PageErrorBoundary>
          <Page />
        </PageErrorBoundary>
      </div>
    </Layout>
  );
}
